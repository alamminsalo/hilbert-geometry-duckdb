load 'build/debug/extension/hilbert_geometry/hilbert_geometry.duckdb_extension';
load spatial;

-- load osm data into table
create table data as select geometry from 'test/sql/files/*.parquet';
select count(*) from data;

-- copy parquet with geometries only for comparison
copy data to 'test/sql/geom.parquet';
copy (select geometry.st_aswkb().hg_encode() as hg from data) to 'test/sql/geom_hg.parquet';
