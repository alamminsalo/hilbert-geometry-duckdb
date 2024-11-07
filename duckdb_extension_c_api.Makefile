# Reusable makefile for all C API based extensions
#
# Inputs
#   EXTENSION_NAME : name of the extension (lower case)
#   MINIMUM_DUCKDB_VERSION : the minimum version of DuckDB that the extension supports
#   EXTENSION_VERSION :
#   DUCKDB_PLATFORM :
#   DUCKDB_TEST_VERSION :
#   DUCKDB_GIT_VERSION :
#   LINUX_CI_IN_DOCKER :
#   SKIP_TESTS :

# TODO clean this up
.PHONY: clean test_debug test_release test debug release install_dev_dependencies all check_configure platform_autodetect platform_override build_extension_with_metadata_debug build_extension_with_metadata_release

.PHONY: platform extension_version

#############################################
### Platform dependent config
#############################################
PYTHON_BIN=python3

ifeq ($(OS),Windows_NT)
	EXTENSION_LIB_FILENAME=$(EXTENSION_NAME).dll
	PYTHON_VENV_BIN=./configure/venv/Scripts/python.exe
else
	PYTHON_VENV_BIN=./configure/venv/bin/python3
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        EXTENSION_LIB_FILENAME=lib$(EXTENSION_NAME).so
    endif
    ifeq ($(UNAME_S),Darwin)
        EXTENSION_LIB_FILENAME=lib$(EXTENSION_NAME).dylib
    endif
endif

#############################################
### Main extension parameters
#############################################

# The minimum DuckDB version that this extension supports
ifeq ($(MINIMUM_DUCKDB_VERSION),)
	MINIMUM_DUCKDB_VERSION = v0.0.1
endif

EXTENSION_FILENAME=$(EXTENSION_NAME).duckdb_extension

#############################################
### Platform Detection
#############################################

# Write the platform we are building for
platform: configure/platform.txt

# Either autodetect or use the provided value
PLATFORM_COMMAND?=
ifeq ($(DUCKDB_PLATFORM),)
    PLATFORM_COMMAND=$(PYTHON_VENV_BIN) extension-ci-tools/scripts/configure_helper.py --duckdb-platform
else
	# Sets the platform using DUCKDB_PLATFORM variable
	PLATFORM_COMMAND=echo $(DUCKDB_PLATFORM) > configure/platform.txt
endif

configure/platform.txt:
	@ $(PLATFORM_COMMAND)

#############################################
### Extension Version Detection
#############################################

# Either autodetect or use the provided value
VERSION_COMMAND?=
ifeq ($(EXTENSION_VERSION),)
    VERSION_COMMAND=$(PYTHON_VENV_BIN) extension-ci-tools/scripts/configure_helper.py --extension-version
else
	# Sets the platform using DUCKDB_PLATFORM variable
	VERSION_COMMAND=echo "$(EXTENSION_VERSION)" > configure/extension_version.txt
endif

extension_version: configure/extension_version.txt

configure/extension_version.txt:
	@ $(VERSION_COMMAND)

#############################################
### Testing
#############################################

# Note: to override the default test runner, create a symlink to a different venv
TEST_RUNNER=$(PYTHON_VENV_BIN) -m duckdb_sqllogictest

TEST_RUNNER_BASE=$(TEST_RUNNER) --test-dir test/sql $(EXTRA_EXTENSIONS_PARAM)
TEST_RUNNER_DEBUG=$(TEST_RUNNER_BASE) --external-extension build/debug/rusty_quack.duckdb_extension
TEST_RUNNER_RELEASE=$(TEST_RUNNER_BASE) --external-extension build/release/rusty_quack.duckdb_extension

# By default latest duckdb is installed, set DUCKDB_TEST_VERSION to switch to a different version
DUCKDB_INSTALL_VERSION?=
ifneq ($(DUCKDB_TEST_VERSION),)
	DUCKDB_INSTALL_VERSION===$(DUCKDB_TEST_VERSION)
endif

ifneq ($(DUCKDB_GIT_VERSION),)
	DUCKDB_INSTALL_VERSION===$(DUCKDB_GIT_VERSION)
endif

# Main tests
test: test_release

TEST_RELEASE_TARGET=test_extension_release_internal
TEST_DEBUG_TARGET=test_extension_debug_internal

# Disable testing outside docker: the unittester is currently dynamically linked by default
ifeq ($(LINUX_CI_IN_DOCKER),1)
	SKIP_TESTS=1
endif

# TODO: for some weird reason the Ubuntu 22.04 Runners on Github Actions don't actually grab the glibc 2.24 wheels but the
#       gilbc 2.17 ones. What this means is that we can't run the tests on linux_amd64 because we are installing the duckdb
#	    linux_amd64_gcc4 test runner
ifeq ($(DUCKDB_PLATFORM),linux_amd64)
	SKIP_TESTS=1
endif

ifeq ($(SKIP_TESTS),1)
	TEST_RELEASE_TARGET=tests_skipped
	TEST_DEBUG_TARGET=tests_skipped
endif

test_extension_release: $(TEST_RELEASE_TARGET)
test_extension_debug: $(TEST_DEBUG_TARGET)

test_extension_release_internal: check_configure
	@echo "Running RELEASE tests.."
	@$(TEST_RUNNER_RELEASE)

test_extension_debug_internal: check_configure
	@echo "Running DEBUG tests.."
	@$(TEST_RUNNER_DEBUG)

tests_skipped:
	@echo "Skipping tests.."


#############################################
### Misc
#############################################

clean_build:
	rm -rf build
	rm -rf duckdb_unittest_tempdir

clean_configure:
	rm -rf configure

nop:
	@echo "NOP"

set_MINIMUM_DUCKDB_VERSION: nop

set_duckdb_tag: nop

set_duckdb_version: nop

output_distribution_matrix:
	cat extension-ci-tools/config/distribution_matrix.json

#############################################
### Building
#############################################
build_extension_with_metadata_debug: check_configure
	$(PYTHON_VENV_BIN) extension-ci-tools/scripts/append_extension_metadata.py \
			-l build/debug/$(EXTENSION_LIB_FILENAME) \
			-o build/debug/$(EXTENSION_FILENAME) \
			-n $(EXTENSION_NAME) \
			-dv $(MINIMUM_DUCKDB_VERSION) \
			-evf configure/extension_version.txt \
			-pf configure/platform.txt
	$(PYTHON_VENV_BIN) -c "import shutil;shutil.copyfile('build/debug/$(EXTENSION_FILENAME)', 'build/debug/extension/$(EXTENSION_NAME)/$(EXTENSION_FILENAME)')"

build_extension_with_metadata_release: check_configure
	$(PYTHON_VENV_BIN) extension-ci-tools/scripts/append_extension_metadata.py \
			-l build/release/$(EXTENSION_LIB_FILENAME) \
			-o build/release/$(EXTENSION_FILENAME) \
			-n $(EXTENSION_NAME) \
			-dv $(MINIMUM_DUCKDB_VERSION) \
			-evf configure/extension_version.txt \
			-pf configure/platform.txt
	$(PYTHON_VENV_BIN) -c "import shutil;shutil.copyfile('build/release/$(EXTENSION_FILENAME)', 'build/release/extension/$(EXTENSION_FILENAME)/$(EXTENSION_FILENAME)')"

#############################################
### Python
#############################################

# Installs the test runner using the selected DuckDB version (latest stable by default)
# TODO: switch to PyPI distribution
venv: configure/venv

configure/venv:
	$(PYTHON_BIN) -m venv configure/venv
	$(PYTHON_VENV_BIN) -m pip install 'duckdb$(DUCKDB_INSTALL_VERSION)'
	$(PYTHON_VENV_BIN) -m pip install git+https://github.com/duckdb/duckdb-sqllogictest-python

#############################################
### Configure
#############################################

CONFIGURE_CI_STEP?=
ifeq ($(LINUX_CI_IN_DOCKER),1)
	CONFIGURE_CI_STEP=nop
else
	CONFIGURE_CI_STEP=configure
endif

configure_ci: $(CONFIGURE_CI_STEP)

# Because the configure_ci may differ from configure, we don't automatically run configure on make build, this makes the error a bit nicer
check_configure:
	@$(PYTHON_BIN) -c "import os; assert os.path.exists('configure/platform.txt'), 'The configure step appears to not be run. Please try running make configure'"
	@$(PYTHON_BIN) -c "import os; assert os.path.exists('configure/venv'), 'The configure step appears to not be run. Please try running make configure'"