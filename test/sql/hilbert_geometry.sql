load 'build/debug/extension/hilbert_geometry/hilbert_geometry.duckdb_extension';
load spatial;

-- Outputs POINT(1 1) geometry
select st_aswkb('POINT(1 1)').hg_encode().hg_decode().st_geomfromwkb();
