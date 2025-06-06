# Hilbert Geometry Duckdb Extension

This is an **experimental** extension for serializing WKB geometries into hilbert-encoded binaries (HWKB).

Creates the following functions:

- `hg_encode(BLOB) -> BLOB` -> Encode WKB into HWKB
- `hg_decode(BLOB) -> BLOB` -> Decode HWKB into WKB

## Usage

```sql
load spatial;
load 'hilbert_geometry';

-- Encode Geometry -> WKB -> HWKB
SELECT st_aswkb('POINT(1 1)'::geometry).hg_encode();
-- \x00\x1C\xC0\x9C7@\x1E\x1D?

-- Decode HWKB -> WKB -> Geometry
SELECT hg_decode('\x00\x1C\xC0\x9C7@\x1E\x1D?'::blob).st_geomfromwkb();
-- POINT (1 1)
```

## Examples

Running the [osm.sql](test/sql/osm.sql) extracts a regional OSM dataset and writes parquet files with both WKB and HWKB encoded geometries.

```
# Execute test script
duckdb -unsigned -bail < test/sql/osm.sql

# Check output file sizes
du -sh test/sql/*.parquet

# 1.4M    test/sql/osm_hwkb.parquet
# 3.6M    test/sql/osm_wkb.parquet
```

We see ~60% reduction in size compared to WKB geometries.

## Building

See instructions at [duckdb/extension-template-rs](https://github.com/duckdb/extension-template-rs)
