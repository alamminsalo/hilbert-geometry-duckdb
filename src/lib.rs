use std::error::Error;

use duckdb::core::Inserter;
use duckdb::ffi;
use duckdb::ffi::{duckdb_string_t, duckdb_string_t_data, duckdb_string_t_length};
use duckdb::{
    core::{DataChunkHandle, LogicalTypeId},
    vscalar::{ScalarFunctionSignature, VScalar},
    vtab::arrow::WritableVector,
    Connection, Result,
};
use duckdb_loadable_macros::duckdb_entrypoint_c_api;
use geo_traits::to_geo::ToGeoGeometry;
use geo_types::Geometry;
use hilbert_geometry::HilbertSerializer;
use std::cell::LazyCell;
use wkb;

const SERIALIZER: LazyCell<HilbertSerializer> = LazyCell::new(|| HilbertSerializer::new());

fn duckdb_string_bytes(word: &duckdb_string_t) -> &[u8] {
    unsafe {
        let len = duckdb_string_t_length(*word);
        let c_ptr = duckdb_string_t_data(word as *const _ as *mut _);
        let bytes = std::slice::from_raw_parts(c_ptr as *const u8, len as usize);
        bytes
    }
}

struct HilbertGeometryEncodeFunc;
impl VScalar for HilbertGeometryEncodeFunc {
    type State = ();

    unsafe fn invoke(
        _state: &(),
        input: &mut DataChunkHandle,
        output: &mut dyn WritableVector,
    ) -> Result<(), Box<dyn Error>> {
        for i in 0..input.len() {
            let input_vec = input.flat_vector(i);

            // read input WKB blob
            if let Some(blob) = input_vec
                .as_slice_with_len::<duckdb_string_t>(input.len())
                .first()
            {
                // encode hilbert geom
                let wkb = duckdb_string_bytes(blob);
                let geom: Geometry<f64> = wkb::reader::read_wkb(wkb)?.to_geometry();
                let buf = (*SERIALIZER).encode(&geom)?;

                // write buf to output
                let output_vector = output.flat_vector();
                output_vector.insert(0, buf.as_slice());
            }
        }

        Ok(())
    }

    fn signatures() -> Vec<ScalarFunctionSignature> {
        vec![ScalarFunctionSignature::exact(
            vec![LogicalTypeId::Blob.into()],
            LogicalTypeId::Blob.into(),
        )]
    }
}

struct HilbertGeometryDecodeFunc;
impl VScalar for HilbertGeometryDecodeFunc {
    type State = ();

    unsafe fn invoke(
        _state: &(),
        input: &mut DataChunkHandle,
        output: &mut dyn WritableVector,
    ) -> Result<(), Box<dyn Error>> {
        for i in 0..input.len() {
            let input_vec = input.flat_vector(i);

            // read input WKB blob
            if let Some(blob) = input_vec
                .as_slice_with_len::<duckdb_string_t>(input.len())
                .first()
            {
                // decode hilbert geom
                let hwkb = duckdb_string_bytes(blob);
                let geom = (*SERIALIZER).decode(&hwkb)?;
                let mut buf = vec![];
                wkb::writer::write_geometry(
                    &mut buf,
                    &geom,
                    &wkb::writer::WriteOptions::default(),
                )?;

                // write buf to output
                let output_vector = output.flat_vector();
                output_vector.insert(0, buf.as_slice());
            }
        }

        Ok(())
    }

    fn signatures() -> Vec<ScalarFunctionSignature> {
        vec![ScalarFunctionSignature::exact(
            vec![LogicalTypeId::Blob.into()],
            LogicalTypeId::Blob.into(),
        )]
    }
}

#[duckdb_entrypoint_c_api()]
pub unsafe fn extension_entrypoint(con: Connection) -> Result<(), Box<dyn Error>> {
    LazyCell::force(&SERIALIZER);

    con.register_scalar_function::<HilbertGeometryEncodeFunc>("hg_encode")
        .expect("Failed to register hg_encode() function");
    con.register_scalar_function::<HilbertGeometryDecodeFunc>("hg_decode")
        .expect("Failed to register hg_decode() function");

    Ok(())
}
