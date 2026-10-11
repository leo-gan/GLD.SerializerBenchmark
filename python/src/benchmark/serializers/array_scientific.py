"""HDF5, NetCDF, and ADIOS2 on the array data set.

``grid`` writes one float64 dataset named ``grid`` with dimensions ``x`` then
``y`` and reads it back. ``grid_window`` writes that same array and reads the
interior window with a hyperslab, a NetCDF slice, or an ADIOS selection.

h5py uses the HDF5 core driver and returns the flushed file image. netCDF4
and adios2 have no bytes buffer: the timed call writes a real file or BP5
directory. The buffer handed back to the runner is that NetCDF file, or a
packed copy of the BP5 directory, so the same bytes can be opened again.
"""

from __future__ import annotations

import os
import shutil
import struct
import tempfile
from pathlib import Path
from typing import Any

import numpy as np

from ..data_v2.models import Grid
from .base import Serializer

_TYPES = frozenset({"grid", "grid_window"})


def _xy(grid: Grid) -> np.ndarray:
    """Shape ``(nx, ny)``. Index ``[x, y]`` is catalog ``values[y * nx + x]``."""
    flat = np.asarray(grid.values, dtype=np.float64)
    return np.ascontiguousarray(flat.reshape(grid.ny, grid.nx).T)


def _flat(arr: np.ndarray) -> list[float]:
    """x-fastest order, matching ``Grid.values`` and ``window_values``."""
    return np.ravel(np.asfortranarray(np.asarray(arr)), order="F").tolist()


def _grid(obj: Any) -> Grid:
    if isinstance(obj, Grid):
        return obj
    raise TypeError(f"array row expects one Grid, got {type(obj)!r}")


def _pack_tree(root: Path) -> bytes:
    files = sorted(path for path in root.rglob("*") if path.is_file())
    out = bytearray()
    out += struct.pack("<I", len(files))
    for path in files:
        rel = str(path.relative_to(root)).encode("utf-8")
        data = path.read_bytes()
        out += struct.pack("<H", len(rel))
        out += rel
        out += struct.pack("<Q", len(data))
        out += data
    return bytes(out)


def _unpack_tree(blob: bytes, root: Path) -> None:
    view = memoryview(blob)
    offset = 0
    (count,) = struct.unpack_from("<I", view, offset)
    offset += 4
    for _ in range(count):
        (name_n,) = struct.unpack_from("<H", view, offset)
        offset += 2
        rel = bytes(view[offset : offset + name_n]).decode("utf-8")
        offset += name_n
        (size,) = struct.unpack_from("<Q", view, offset)
        offset += 8
        dest = root / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(view[offset : offset + size])
        offset += size
    if offset != len(blob):
        raise ValueError("ADIOS directory pack is truncated")


class _ArraySerializer(Serializer):
    native_kind = "dataclass"
    stream_mode = "adapted"

    def __init__(self) -> None:
        super().__init__()
        self._type_id = "grid"
        self._window: tuple[int, int, int, int] = (0, 0, 0, 0)

    def supports(self, test_data_name: str) -> bool:
        return test_data_name in _TYPES

    def prepare(self, test_data_name: str, test_data_type: type) -> None:
        super().prepare(test_data_name, test_data_type)
        self._type_id = test_data_name

    def prepare_data(self, obj: Any, test_data_name: str, test_data_type: type) -> Any:
        grid = _grid(obj)
        self._type_id = test_data_name
        self._window = (grid.x0, grid.y0, grid.wx, grid.wy)
        return grid


class H5pySerializer(_ArraySerializer):
    """h5py. Core virtual file driver, one contiguous float64 dataset."""

    package_name = "h5py"

    @property
    def name(self) -> str:
        return "h5py"

    def serialize_bytes(self, obj: Any) -> bytes:
        import h5py

        handle = h5py.File("gld.h5", "w", driver="core", backing_store=False)
        try:
            handle.create_dataset("grid", data=_xy(_grid(obj)), chunks=None)
            handle.flush()
            return bytes(handle.id.get_file_image())
        finally:
            handle.close()

    def deserialize_bytes(self, data: bytes) -> Any:
        import h5py

        access = h5py.h5p.create(h5py.h5p.FILE_ACCESS)
        access.set_fapl_core(backing_store=False)
        access.set_file_image(data)
        fid = h5py.h5f.open(b"gld.h5", h5py.h5f.ACC_RDONLY, fapl=access)
        handle = h5py.File(fid)
        try:
            dataset = handle["grid"]
            if self._type_id == "grid_window":
                x0, y0, wx, wy = self._window
                return _flat(dataset[x0 : x0 + wx, y0 : y0 + wy])
            return _flat(dataset[()])
        finally:
            handle.close()


class NetCdf4Serializer(_ArraySerializer):
    """netCDF4. One NF90-style NetCDF-4 variable. Slices are 0-based."""

    package_name = "netCDF4"

    @property
    def name(self) -> str:
        return "netCDF4"

    def serialize_bytes(self, obj: Any) -> bytes:
        from netCDF4 import Dataset

        grid = _grid(obj)
        fd, name = tempfile.mkstemp(prefix="gld-nc-", suffix=".nc")
        os.close(fd)
        path = Path(name)
        try:
            dataset = Dataset(path, "w", format="NETCDF4")
            try:
                dataset.createDimension("x", grid.nx)
                dataset.createDimension("y", grid.ny)
                var = dataset.createVariable("grid", "f8", ("x", "y"))
                var[:] = _xy(grid)
            finally:
                dataset.close()
            return path.read_bytes()
        finally:
            path.unlink(missing_ok=True)

    def deserialize_bytes(self, data: bytes) -> Any:
        from netCDF4 import Dataset

        fd, name = tempfile.mkstemp(prefix="gld-nc-", suffix=".nc")
        os.close(fd)
        path = Path(name)
        try:
            path.write_bytes(data)
            dataset = Dataset(path, "r")
            try:
                var = dataset.variables["grid"]
                if self._type_id == "grid_window":
                    x0, y0, wx, wy = self._window
                    return _flat(var[x0 : x0 + wx, y0 : y0 + wy])
                return _flat(var[:])
            finally:
                dataset.close()
        finally:
            path.unlink(missing_ok=True)


class Adios2Serializer(_ArraySerializer):
    """Official ADIOS2 Python API. Serial BP5 directory, one variable."""

    package_name = "adios2"

    @property
    def name(self) -> str:
        return "adios2"

    def serialize_bytes(self, obj: Any) -> bytes:
        import adios2

        root = Path(tempfile.mkdtemp(prefix="gld-ad-"))
        try:
            with adios2.Stream(str(root), "w") as stream:
                stream.write("grid", _xy(_grid(obj)))
            return _pack_tree(root)
        finally:
            shutil.rmtree(root, ignore_errors=True)

    def deserialize_bytes(self, data: bytes) -> Any:
        import adios2

        root = Path(tempfile.mkdtemp(prefix="gld-ad-"))
        try:
            _unpack_tree(data, root)
            with adios2.Stream(str(root), "r") as stream:
                for _step in stream.steps():
                    if self._type_id == "grid_window":
                        x0, y0, wx, wy = self._window
                        values = stream.read("grid", start=[x0, y0], count=[wx, wy])
                    else:
                        values = stream.read("grid")
                    return _flat(values)
            raise RuntimeError("ADIOS2 file has no step")
        finally:
            shutil.rmtree(root, ignore_errors=True)
