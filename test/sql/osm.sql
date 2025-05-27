--
LOAD 'build/debug/extension/hilbert_geometry/hilbert_geometry.duckdb_extension';
LOAD spatial;

SET s3_region='us-west-2';

-- Read overturemaps OSM data from Osaka, Japan
CREATE TABLE data AS
    SELECT
       geometry   -- DuckDB v.1.1.0 will autoload this as a `geometry` type
    FROM read_parquet('s3://overturemaps-us-west-2/release/2025-05-21.0/**/*.parquet', filename=true, hive_partitioning=1)
    WHERE TRUE
      AND bbox.xmin > 135.178528
      AND bbox.ymin > 34.438628
      AND bbox.xmax < 135.796509
      AND bbox.ymax < 34.883678
;


-- copy parquet with geometries only for comparison
copy data to 'test/sql/osm_wkb.parquet';
copy (select geometry.st_aswkb().hg_encode() as hg from data) to 'test/sql/osm_hwkb.parquet';
