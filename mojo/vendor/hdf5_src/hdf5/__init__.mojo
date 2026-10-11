from std.collections import Span

from hdf5_runtime.doc import (
    DT_F32,
    DT_F64,
    DT_I16,
    DT_I32,
    DT_I64,
    DT_I8,
    DT_STR,
    DT_U16,
    DT_U32,
    DT_U64,
    DT_U8,
    SUPERBLOCK_VERSION,
    BpStep,
    H5Doc,
    NcFile,
    dtype_name,
    elem_size,
)
from hdf5_wire.bp5 import read_bp5, write_bp5
from hdf5_wire.hdf5 import read_hdf5, write_hdf5
from hdf5_wire.netcdf import read_cdf1, read_nc4, write_cdf1, write_nc4

comptime VERSION = "0.2.0"


def read_hdf5_path(path: String) raises -> H5Doc:
    var handle = open(path, "r")
    var data = handle.read_bytes()
    handle.close()
    return read_hdf5(Span(data))


def write_hdf5_path(path: String, doc: H5Doc) raises:
    var raw = write_hdf5(doc)
    var handle = open(path, "w")
    handle.write_bytes(Span(raw))
    handle.close()
