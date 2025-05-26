#!/bin/bash

uv venv
source .venv/bin/activate
uv pip install "quackosm[cli]"
quackosm --geom-filter-geocode "Shibuya, Tokyo"
