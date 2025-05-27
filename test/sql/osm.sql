--
LOAD 'build/release/hilbert_geometry.duckdb_extension';
LOAD spatial;

SET s3_region='us-west-2';

.print 'Reading OSM data from Osaka, Japan...'
CREATE TABLE data AS
    SELECT
       geometry
    FROM read_parquet('s3://overturemaps-us-west-2/release/2025-05-21.0/theme=*/type=*/*.parquet', hive_partitioning=1)
    WHERE TRUE
    AND theme IN ('building', 'places', 'transportation')
    AND bbox.xmin > 135.42
    AND bbox.ymin > 34.62
    AND bbox.xmax < 135.52
    AND bbox.ymax < 34.72
;


.print 'Creating parquet files...'
copy data to 'test/sql/osm_wkb.parquet';
copy (select geometry.st_aswkb().hg_encode() as hg from data) to 'test/sql/osm_hwkb.parquet';
