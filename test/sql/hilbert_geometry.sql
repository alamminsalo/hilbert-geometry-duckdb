load 'build/debug/extension/hilbert_geometry/hilbert_geometry.duckdb_extension';
load spatial;

-- load osm data into table
create table data as select geometry from 'test/sql/files/*.parquet';
select count(*) from data;

-- check how many geometries differ
copy (
	with pairs as (
		select
			a: geometry,
			b: a.st_aswkb().hg_encode().hg_decode().st_geomfromwkb()
		from data
	)
	select
		a: a.st_astext(),
		b: b.st_astext(),
	from pairs
	where a != b
) to 'test/sql/diff.parquet';

-- copy parquet with geometries only for comparison
copy data to 'test/sql/geom.parquet';
copy (select geometry.st_aswkb().hg_encode() as hg from data) to 'test/sql/geom_hg.parquet';

-- create fgb files for inspection
copy data to 'test/sql/geom.fgb' (format gdal, driver FlatGeobuf, srs 'EPSG:4326');
copy (select geometry.st_aswkb().hg_encode().hg_decode().st_geomfromwkb() as hg from data) to 'test/sql/geom_hg.fgb' (format gdal, driver FlatGeobuf, srs 'EPSG:4326');
