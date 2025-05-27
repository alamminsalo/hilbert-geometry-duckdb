# Hilbert Geometry Duckdb Extension

This is an **experimental** extension for serializing WKB geometries into hilbert-encoded binaries (HWKB).

Creates the following functions:

- `hg_encode(BLOB) -> BLOB` -> Encode WKB into HWKB
- `hg_decode(BLOB) -> BLOB` -> Decode HWKB into WKB

## Usage

```sql
load spatial;
load 'hilbert_geometry';

-- Encode WKB geometry to binary-encoded hilbert geometry
SELECT st_aswkb('POINT(1 1)'::geometry).hg_encode();

-- Decode hilbert-encoded geometry to WKB and parse Geometry
SELECT hg_decode('\x00\x1C\xC0\x9C7@\x1E\x1D?'::blob).st_geomfromwkb();
```

## Building

See instructions at [duckdb/extension-template-rs](https://github.com/duckdb/extension-template-rs)
