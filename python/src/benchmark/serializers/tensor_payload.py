"""Tensor data set for the Python rows that already store numeric arrays.

``tensor`` and ``shard`` are float32, row-major. ``prompt`` is int64.
``request`` is a request id, a model name, a float32 temperature, and the prompt.
``tensor_view`` writes the same matrix as ``tensor`` and returns a buffer
that aliases the encoded bytes. A copy is not a view.

Building the host arrays is prepare. The timed call writes and reads.
"""

from __future__ import annotations

import os
import shutil
import struct
import tempfile
from pathlib import Path
from typing import Any

import numpy as np

from ..data_v2.models import InferenceRequest, Prompt, Shard, TensorMatrix
from .array_scientific import _pack_tree, _unpack_tree

TENSOR_OWNED = frozenset({"tensor", "tensor_view", "prompt", "shard", "request"})
TENSOR_VIEW_OK = frozenset({"arrow-ipc", "flatbuffers"})


def _f32(values: Any, shape: tuple[int, ...]) -> np.ndarray:
    flat = np.asarray(values, dtype=np.float32)
    return np.ascontiguousarray(flat.reshape(shape))


def _i64(values: Any, shape: tuple[int, ...]) -> np.ndarray:
    flat = np.asarray(values, dtype=np.int64)
    return np.ascontiguousarray(flat.reshape(shape))


def _flat_f32(arr: np.ndarray) -> list[float]:
    return [float(x) for x in np.ascontiguousarray(arr, dtype=np.float32).reshape(-1)]


def _flat_i64(arr: np.ndarray) -> list[int]:
    return [int(x) for x in np.ascontiguousarray(arr, dtype=np.int64).reshape(-1)]


def _matrix(obj: Any) -> TensorMatrix:
    if isinstance(obj, TensorMatrix):
        return obj
    raise TypeError(f"tensor row expects TensorMatrix, got {type(obj)!r}")


def _prompt(obj: Any) -> Prompt:
    if isinstance(obj, Prompt):
        return obj
    raise TypeError(f"prompt row expects Prompt, got {type(obj)!r}")


def _shard(obj: Any) -> Shard:
    if isinstance(obj, Shard):
        return obj
    raise TypeError(f"shard row expects Shard, got {type(obj)!r}")


def _request(obj: Any) -> InferenceRequest:
    if isinstance(obj, InferenceRequest):
        return obj
    raise TypeError(f"request row expects InferenceRequest, got {type(obj)!r}")


def _prompt_from_arrays(
    batch: int,
    seq: int,
    input_ids: np.ndarray,
    attention_mask: np.ndarray,
    position_ids: np.ndarray,
) -> Prompt:
    return Prompt(
        batch=batch,
        seq=seq,
        input_ids=_flat_i64(input_ids),
        attention_mask=_flat_i64(attention_mask),
        position_ids=_flat_i64(position_ids),
    )


def _span(blob: Any) -> tuple[int, int]:
    address = getattr(blob, "address", None)
    size = getattr(blob, "size", None)
    if address is not None and size is not None:
        return int(address), int(size)
    view = blob if isinstance(blob, memoryview) else memoryview(blob)
    if len(view) == 0:
        return 0, 0
    start = int(np.frombuffer(view, dtype=np.uint8).__array_interface__["data"][0])
    return start, len(view)


def _payload_ptr(values: Any) -> tuple[int, bool]:
    arr = np.asarray(values)
    if isinstance(values, memoryview):
        arr = np.asarray(values, dtype=np.float32)
    owns = bool(getattr(arr.flags, "owndata", True)) if not isinstance(values, memoryview) else False
    ptr = int(arr.__array_interface__["data"][0])
    if isinstance(values, memoryview):
        raw = np.frombuffer(values.cast("B"), dtype=np.uint8)
        ptr = int(raw.__array_interface__["data"][0])
        owns = False
    return ptr, owns


def _view_matrix(obj: TensorMatrix, values: Any, blob: Any) -> TensorMatrix:
    """Return the matrix only when ``values`` borrows ``blob``."""
    ptr, owns = _payload_ptr(values)
    if owns:
        raise RuntimeError("tensor_view materialized a copy")
    start, size = _span(blob)
    if not (start <= ptr < start + size):
        raise RuntimeError("tensor_view payload is outside the encoded buffer")
    if isinstance(values, memoryview):
        kept: Any = values
    else:
        kept = np.asarray(values).reshape(-1)
    return TensorMatrix(rows=obj.rows, cols=obj.cols, values=kept)


# --- HDF5 / h5py -----------------------------------------------------------

def h5_write(obj: Any, type_id: str) -> bytes:
    import h5py

    handle = h5py.File("gld-tensor.h5", "w", driver="core", backing_store=False)
    try:
        _h5_fill(handle, obj, type_id)
        handle.flush()
        return bytes(handle.id.get_file_image())
    finally:
        handle.close()


def h5_read(data: bytes, type_id: str) -> Any:
    import h5py

    access = h5py.h5p.create(h5py.h5p.FILE_ACCESS)
    access.set_fapl_core(backing_store=False)
    access.set_file_image(data)
    fid = h5py.h5f.open(b"gld-tensor.h5", h5py.h5f.ACC_RDONLY, fapl=access)
    handle = h5py.File(fid)
    try:
        return _h5_load(handle, type_id)
    finally:
        handle.close()


def _h5_fill(handle: Any, obj: Any, type_id: str) -> None:
    if type_id in ("tensor", "tensor_view"):
        matrix = _matrix(obj)
        handle.create_dataset(
            "values", data=_f32(matrix.values, (matrix.rows, matrix.cols)), chunks=None
        )
        return
    if type_id == "prompt":
        _h5_prompt(handle, _prompt(obj))
        return
    if type_id == "shard":
        shard = _shard(obj)
        handle.create_dataset(
            "tok_emb", data=_f32(shard.tok_emb, (shard.vocab, shard.hidden)), chunks=None
        )
        handle.create_dataset(
            "attn", data=_f32(shard.attn, (shard.hidden, shard.hidden)), chunks=None
        )
        handle.create_dataset(
            "ffn", data=_f32(shard.ffn_weight, (shard.ffn, shard.hidden)), chunks=None
        )
        handle.create_dataset("norm", data=_f32(shard.norm, (shard.hidden,)), chunks=None)
        return
    if type_id == "request":
        req = _request(obj)
        handle.attrs["request_id"] = np.int64(req.request_id)
        handle.attrs["model"] = req.model
        handle.attrs["temperature"] = np.float32(req.temperature)
        _h5_prompt(handle, req.inputs)
        return
    raise TypeError(type_id)


def _h5_prompt(handle: Any, prompt: Prompt) -> None:
    shape = (prompt.batch, prompt.seq)
    handle.create_dataset("input_ids", data=_i64(prompt.input_ids, shape), chunks=None)
    handle.create_dataset("attention_mask", data=_i64(prompt.attention_mask, shape), chunks=None)
    handle.create_dataset("position_ids", data=_i64(prompt.position_ids, shape), chunks=None)


def _h5_load(handle: Any, type_id: str) -> Any:
    if type_id in ("tensor", "tensor_view"):
        values = handle["values"]
        return TensorMatrix(
            rows=int(values.shape[0]),
            cols=int(values.shape[1]),
            values=_flat_f32(values[()]),
        )
    if type_id == "prompt":
        return _h5_load_prompt(handle)
    if type_id == "shard":
        emb = handle["tok_emb"]
        attn = handle["attn"]
        ffn = handle["ffn"]
        norm = handle["norm"]
        return Shard(
            vocab=int(emb.shape[0]),
            hidden=int(emb.shape[1]),
            ffn=int(ffn.shape[0]),
            tok_emb=_flat_f32(emb[()]),
            attn=_flat_f32(attn[()]),
            ffn_weight=_flat_f32(ffn[()]),
            norm=_flat_f32(norm[()]),
        )
    if type_id == "request":
        return InferenceRequest(
            request_id=int(handle.attrs["request_id"]),
            model=str(handle.attrs["model"]),
            temperature=float(np.float32(handle.attrs["temperature"])),
            inputs=_h5_load_prompt(handle),
        )
    raise TypeError(type_id)


def _h5_load_prompt(handle: Any) -> Prompt:
    ids = handle["input_ids"]
    return _prompt_from_arrays(
        int(ids.shape[0]),
        int(ids.shape[1]),
        ids[()],
        handle["attention_mask"][()],
        handle["position_ids"][()],
    )


# --- NetCDF4 ---------------------------------------------------------------

def nc_write(obj: Any, type_id: str) -> bytes:
    from netCDF4 import Dataset

    fd, name = tempfile.mkstemp(prefix="gld-tn-", suffix=".nc")
    os.close(fd)
    path = Path(name)
    try:
        dataset = Dataset(path, "w", format="NETCDF4")
        try:
            _nc_fill(dataset, obj, type_id)
        finally:
            dataset.close()
        return path.read_bytes()
    finally:
        path.unlink(missing_ok=True)


def nc_read(data: bytes, type_id: str) -> Any:
    from netCDF4 import Dataset

    fd, name = tempfile.mkstemp(prefix="gld-tn-", suffix=".nc")
    os.close(fd)
    path = Path(name)
    try:
        path.write_bytes(data)
        dataset = Dataset(path, "r")
        try:
            return _nc_load(dataset, type_id)
        finally:
            dataset.close()
    finally:
        path.unlink(missing_ok=True)


def _nc_dims(dataset: Any, **sizes: int) -> None:
    for name, size in sizes.items():
        if name not in dataset.dimensions:
            dataset.createDimension(name, size)


def _nc_fill(dataset: Any, obj: Any, type_id: str) -> None:
    if type_id in ("tensor", "tensor_view"):
        matrix = _matrix(obj)
        _nc_dims(dataset, row=matrix.rows, col=matrix.cols)
        var = dataset.createVariable("values", "f4", ("row", "col"))
        var[:] = _f32(matrix.values, (matrix.rows, matrix.cols))
        return
    if type_id == "prompt":
        _nc_prompt(dataset, _prompt(obj))
        return
    if type_id == "shard":
        shard = _shard(obj)
        _nc_dims(dataset, vocab=shard.vocab, hidden=shard.hidden, ffn=shard.ffn)
        dataset.createVariable("tok_emb", "f4", ("vocab", "hidden"))[:] = _f32(
            shard.tok_emb, (shard.vocab, shard.hidden)
        )
        dataset.createVariable("attn", "f4", ("hidden", "hidden"))[:] = _f32(
            shard.attn, (shard.hidden, shard.hidden)
        )
        dataset.createVariable("ffn", "f4", ("ffn", "hidden"))[:] = _f32(
            shard.ffn_weight, (shard.ffn, shard.hidden)
        )
        dataset.createVariable("norm", "f4", ("hidden",))[:] = _f32(shard.norm, (shard.hidden,))
        return
    if type_id == "request":
        req = _request(obj)
        dataset.setncattr("request_id", np.int64(req.request_id))
        dataset.setncattr("model", req.model)
        dataset.setncattr("temperature", np.float32(req.temperature))
        _nc_prompt(dataset, req.inputs)
        return
    raise TypeError(type_id)


def _nc_prompt(dataset: Any, prompt: Prompt) -> None:
    _nc_dims(dataset, batch=prompt.batch, seq=prompt.seq)
    shape = (prompt.batch, prompt.seq)
    dataset.createVariable("input_ids", "i8", ("batch", "seq"))[:] = _i64(prompt.input_ids, shape)
    dataset.createVariable("attention_mask", "i8", ("batch", "seq"))[:] = _i64(
        prompt.attention_mask, shape
    )
    dataset.createVariable("position_ids", "i8", ("batch", "seq"))[:] = _i64(
        prompt.position_ids, shape
    )


def _nc_load(dataset: Any, type_id: str) -> Any:
    if type_id in ("tensor", "tensor_view"):
        values = dataset.variables["values"]
        return TensorMatrix(rows=int(values.shape[0]), cols=int(values.shape[1]), values=_flat_f32(values[:]))
    if type_id == "prompt":
        return _nc_load_prompt(dataset)
    if type_id == "shard":
        emb = dataset.variables["tok_emb"]
        ffn = dataset.variables["ffn"]
        return Shard(
            vocab=int(emb.shape[0]),
            hidden=int(emb.shape[1]),
            ffn=int(ffn.shape[0]),
            tok_emb=_flat_f32(emb[:]),
            attn=_flat_f32(dataset.variables["attn"][:]),
            ffn_weight=_flat_f32(ffn[:]),
            norm=_flat_f32(dataset.variables["norm"][:]),
        )
    if type_id == "request":
        return InferenceRequest(
            request_id=int(dataset.getncattr("request_id")),
            model=str(dataset.getncattr("model")),
            temperature=float(np.float32(dataset.getncattr("temperature"))),
            inputs=_nc_load_prompt(dataset),
        )
    raise TypeError(type_id)


def _nc_load_prompt(dataset: Any) -> Prompt:
    ids = dataset.variables["input_ids"]
    return _prompt_from_arrays(
        int(ids.shape[0]),
        int(ids.shape[1]),
        ids[:],
        dataset.variables["attention_mask"][:],
        dataset.variables["position_ids"][:],
    )


# --- ADIOS2 ----------------------------------------------------------------

def adios_write(obj: Any, type_id: str) -> bytes:
    import adios2

    root = Path(tempfile.mkdtemp(prefix="gld-tad-"))
    try:
        with adios2.Stream(str(root), "w") as stream:
            _adios_fill(stream, obj, type_id)
        return _pack_tree(root)
    finally:
        shutil.rmtree(root, ignore_errors=True)


def adios_read(data: bytes, type_id: str) -> Any:
    import adios2

    root = Path(tempfile.mkdtemp(prefix="gld-tad-"))
    try:
        _unpack_tree(data, root)
        with adios2.Stream(str(root), "r") as stream:
            for _step in stream.steps():
                return _adios_load(stream, type_id)
        raise RuntimeError("ADIOS2 file has no step")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def _adios_fill(stream: Any, obj: Any, type_id: str) -> None:
    if type_id in ("tensor", "tensor_view"):
        matrix = _matrix(obj)
        stream.write("values", _f32(matrix.values, (matrix.rows, matrix.cols)))
        return
    if type_id == "prompt":
        _adios_prompt(stream, _prompt(obj))
        return
    if type_id == "shard":
        shard = _shard(obj)
        stream.write("tok_emb", _f32(shard.tok_emb, (shard.vocab, shard.hidden)))
        stream.write("attn", _f32(shard.attn, (shard.hidden, shard.hidden)))
        stream.write("ffn", _f32(shard.ffn_weight, (shard.ffn, shard.hidden)))
        stream.write("norm", _f32(shard.norm, (shard.hidden,)))
        return
    if type_id == "request":
        req = _request(obj)
        stream.write_attribute("request_id", np.int64(req.request_id))
        stream.write_attribute("model", req.model)
        stream.write_attribute("temperature", np.float32(req.temperature))
        _adios_prompt(stream, req.inputs)
        return
    raise TypeError(type_id)


def _adios_prompt(stream: Any, prompt: Prompt) -> None:
    shape = (prompt.batch, prompt.seq)
    stream.write("input_ids", _i64(prompt.input_ids, shape))
    stream.write("attention_mask", _i64(prompt.attention_mask, shape))
    stream.write("position_ids", _i64(prompt.position_ids, shape))


def _adios_load(stream: Any, type_id: str) -> Any:
    if type_id in ("tensor", "tensor_view"):
        values = np.asarray(stream.read("values"))
        return TensorMatrix(rows=int(values.shape[0]), cols=int(values.shape[1]), values=_flat_f32(values))
    if type_id == "prompt":
        return _adios_load_prompt(stream)
    if type_id == "shard":
        emb = np.asarray(stream.read("tok_emb"))
        attn = np.asarray(stream.read("attn"))
        ffn = np.asarray(stream.read("ffn"))
        norm = np.asarray(stream.read("norm"))
        return Shard(
            vocab=int(emb.shape[0]),
            hidden=int(emb.shape[1]),
            ffn=int(ffn.shape[0]),
            tok_emb=_flat_f32(emb),
            attn=_flat_f32(attn),
            ffn_weight=_flat_f32(ffn),
            norm=_flat_f32(norm),
        )
    if type_id == "request":
        return InferenceRequest(
            request_id=int(stream.read_attribute("request_id")),
            model=str(stream.read_attribute_string("model")),
            temperature=float(np.float32(stream.read_attribute("temperature"))),
            inputs=_adios_load_prompt(stream),
        )
    raise TypeError(type_id)


def _adios_load_prompt(stream: Any) -> Prompt:
    ids = np.asarray(stream.read("input_ids"))
    return _prompt_from_arrays(
        int(ids.shape[0]),
        int(ids.shape[1]),
        ids,
        np.asarray(stream.read("attention_mask")),
        np.asarray(stream.read("position_ids")),
    )


# --- Arrow IPC tensor messages --------------------------------------------

def arrow_write(obj: Any, type_id: str) -> bytes:
    import pyarrow as pa
    import pyarrow.ipc as ipc

    sink = pa.BufferOutputStream()
    if type_id == "request":
        req = _request(obj)
        for array in _arrow_arrays(req.inputs, "prompt"):
            ipc.write_tensor(pa.Tensor.from_numpy(np.ascontiguousarray(array)), sink)
        batch = pa.record_batch(
            [
                pa.array([req.request_id], type=pa.int64()),
                pa.array([req.model], type=pa.string()),
                pa.array([np.float32(req.temperature)], type=pa.float32()),
            ],
            names=["request_id", "model", "temperature"],
        )
        with ipc.new_stream(sink, batch.schema) as writer:
            writer.write_batch(batch)
        return sink.getvalue().to_pybytes()
    for array in _arrow_arrays(obj, type_id):
        ipc.write_tensor(pa.Tensor.from_numpy(np.ascontiguousarray(array)), sink)
    return sink.getvalue().to_pybytes()


def arrow_read(data: bytes, type_id: str, *, view: bool) -> Any:
    import pyarrow as pa
    import pyarrow.ipc as ipc

    buf = pa.py_buffer(data)
    reader = pa.BufferReader(buf)
    if type_id == "request":
        tensors = [ipc.read_tensor(reader) for _ in range(3)]
        rest = data[reader.tell() :]
        table = ipc.open_stream(pa.py_buffer(rest)).read_all()
        row = table.to_pylist()[0]
        prompt = _prompt_from_arrays(
            int(tensors[0].shape[0]),
            int(tensors[0].shape[1]),
            tensors[0].to_numpy(),
            tensors[1].to_numpy(),
            tensors[2].to_numpy(),
        )
        return InferenceRequest(
            request_id=int(row["request_id"]),
            model=str(row["model"]),
            temperature=float(np.float32(row["temperature"])),
            inputs=prompt,
        )
    tensors = []
    while reader.tell() < len(data):
        tensors.append(ipc.read_tensor(reader))
    if type_id in ("tensor", "tensor_view"):
        arr = tensors[0].to_numpy()
        matrix = TensorMatrix(rows=int(arr.shape[0]), cols=int(arr.shape[1]), values=arr.reshape(-1))
        if view:
            return _view_matrix(matrix, arr.reshape(-1), buf)
        return TensorMatrix(rows=matrix.rows, cols=matrix.cols, values=_flat_f32(arr))
    if type_id == "prompt":
        return _prompt_from_arrays(
            int(tensors[0].shape[0]),
            int(tensors[0].shape[1]),
            tensors[0].to_numpy(),
            tensors[1].to_numpy(),
            tensors[2].to_numpy(),
        )
    if type_id == "shard":
        emb = tensors[0].to_numpy()
        attn = tensors[1].to_numpy()
        ffn = tensors[2].to_numpy()
        norm = tensors[3].to_numpy()
        return Shard(
            vocab=int(emb.shape[0]),
            hidden=int(emb.shape[1]),
            ffn=int(ffn.shape[0]),
            tok_emb=_flat_f32(emb),
            attn=_flat_f32(attn),
            ffn_weight=_flat_f32(ffn),
            norm=_flat_f32(norm),
        )
    raise TypeError(type_id)


def _arrow_arrays(obj: Any, type_id: str) -> list[np.ndarray]:
    if type_id in ("tensor", "tensor_view"):
        matrix = _matrix(obj)
        return [_f32(matrix.values, (matrix.rows, matrix.cols))]
    if type_id == "prompt":
        prompt = _prompt(obj)
        shape = (prompt.batch, prompt.seq)
        return [
            _i64(prompt.input_ids, shape),
            _i64(prompt.attention_mask, shape),
            _i64(prompt.position_ids, shape),
        ]
    if type_id == "shard":
        shard = _shard(obj)
        return [
            _f32(shard.tok_emb, (shard.vocab, shard.hidden)),
            _f32(shard.attn, (shard.hidden, shard.hidden)),
            _f32(shard.ffn_weight, (shard.ffn, shard.hidden)),
            _f32(shard.norm, (shard.hidden,)),
        ]
    raise TypeError(type_id)


# --- FlatBuffers -----------------------------------------------------------

def fb_write(builder: Any, obj: Any, type_id: str) -> bytes:
    if type_id in ("tensor", "tensor_view"):
        return _fb_matrix(builder, _matrix(obj))
    if type_id == "prompt":
        return _fb_prompt(builder, _prompt(obj))
    if type_id == "shard":
        return _fb_shard(builder, _shard(obj))
    if type_id == "request":
        return _fb_request(builder, _request(obj))
    raise TypeError(type_id)


def fb_read(data: bytes, type_id: str, *, view: bool) -> Any:
    table = _root(data)
    if type_id in ("tensor", "tensor_view"):
        rows = _i32(data, table, 0)
        cols = _i32(data, table, 1)
        values = _vector(data, table, 2, 4, "f", copy=not view)
        if view:
            return _view_matrix(TensorMatrix(rows=rows, cols=cols, values=values), values, data)
        return TensorMatrix(rows=rows, cols=cols, values=values)
    if type_id == "prompt":
        return _fb_read_prompt(data, table)
    if type_id == "shard":
        vocab = _i32(data, table, 0)
        hidden = _i32(data, table, 1)
        ffn = _i32(data, table, 2)
        return Shard(
            vocab=vocab,
            hidden=hidden,
            ffn=ffn,
            tok_emb=_vector(data, table, 3, 4, "f", copy=True),
            attn=_vector(data, table, 4, 4, "f", copy=True),
            ffn_weight=_vector(data, table, 5, 4, "f", copy=True),
            norm=_vector(data, table, 6, 4, "f", copy=True),
        )
    if type_id == "request":
        return InferenceRequest(
            request_id=_i64_slot(data, table, 0),
            model=_string(data, table, 1),
            temperature=_f32_slot(data, table, 2),
            inputs=_fb_read_prompt(data, table, batch_slot=6, seq_slot=7, ids=3, mask=4, pos=5),
        )
    raise TypeError(type_id)


def _fb_matrix(builder: Any, matrix: TensorMatrix) -> bytes:
    builder.Clear()
    vec = builder.CreateNumpyVector(_f32(matrix.values, (matrix.rows * matrix.cols,)))
    builder.StartObject(3)
    builder.PrependUOffsetTRelativeSlot(2, vec, 0)
    builder.PrependInt32Slot(1, matrix.cols, 0)
    builder.PrependInt32Slot(0, matrix.rows, 0)
    builder.Finish(builder.EndObject())
    return bytes(builder.Output())


def _fb_prompt(builder: Any, prompt: Prompt, *, slots: tuple[int, int, int, int, int] | None = None) -> int | bytes:
    """Write a prompt. Without ``slots`` this finishes a standalone buffer."""
    standalone = slots is None
    batch_s, seq_s, ids_s, mask_s, pos_s = slots or (0, 1, 2, 3, 4)
    if standalone:
        builder.Clear()
    ids = builder.CreateNumpyVector(_i64(prompt.input_ids, (len(prompt.input_ids),)))
    mask = builder.CreateNumpyVector(_i64(prompt.attention_mask, (len(prompt.attention_mask),)))
    pos = builder.CreateNumpyVector(_i64(prompt.position_ids, (len(prompt.position_ids),)))
    width = 5 if standalone else 8
    builder.StartObject(width)
    builder.PrependUOffsetTRelativeSlot(pos_s, pos, 0)
    builder.PrependUOffsetTRelativeSlot(mask_s, mask, 0)
    builder.PrependUOffsetTRelativeSlot(ids_s, ids, 0)
    builder.PrependInt32Slot(seq_s, prompt.seq, 0)
    builder.PrependInt32Slot(batch_s, prompt.batch, 0)
    root = builder.EndObject()
    if not standalone:
        return root
    builder.Finish(root)
    return bytes(builder.Output())


def _fb_shard(builder: Any, shard: Shard) -> bytes:
    builder.Clear()
    emb = builder.CreateNumpyVector(_f32(shard.tok_emb, (len(shard.tok_emb),)))
    attn = builder.CreateNumpyVector(_f32(shard.attn, (len(shard.attn),)))
    ffn = builder.CreateNumpyVector(_f32(shard.ffn_weight, (len(shard.ffn_weight),)))
    norm = builder.CreateNumpyVector(_f32(shard.norm, (len(shard.norm),)))
    builder.StartObject(7)
    builder.PrependUOffsetTRelativeSlot(6, norm, 0)
    builder.PrependUOffsetTRelativeSlot(5, ffn, 0)
    builder.PrependUOffsetTRelativeSlot(4, attn, 0)
    builder.PrependUOffsetTRelativeSlot(3, emb, 0)
    builder.PrependInt32Slot(2, shard.ffn, 0)
    builder.PrependInt32Slot(1, shard.hidden, 0)
    builder.PrependInt32Slot(0, shard.vocab, 0)
    builder.Finish(builder.EndObject())
    return bytes(builder.Output())


def _fb_request(builder: Any, req: InferenceRequest) -> bytes:
    builder.Clear()
    model = builder.CreateString(req.model)
    ids = builder.CreateNumpyVector(_i64(req.inputs.input_ids, (len(req.inputs.input_ids),)))
    mask = builder.CreateNumpyVector(_i64(req.inputs.attention_mask, (len(req.inputs.attention_mask),)))
    pos = builder.CreateNumpyVector(_i64(req.inputs.position_ids, (len(req.inputs.position_ids),)))
    builder.StartObject(8)
    builder.PrependInt32Slot(7, req.inputs.seq, 0)
    builder.PrependInt32Slot(6, req.inputs.batch, 0)
    builder.PrependUOffsetTRelativeSlot(5, pos, 0)
    builder.PrependUOffsetTRelativeSlot(4, mask, 0)
    builder.PrependUOffsetTRelativeSlot(3, ids, 0)
    builder.PrependFloat32Slot(2, float(req.temperature), 0.0)
    builder.PrependUOffsetTRelativeSlot(1, model, 0)
    builder.PrependInt64Slot(0, int(req.request_id), 0)
    builder.Finish(builder.EndObject())
    return bytes(builder.Output())


def _root(data: bytes) -> int:
    return struct.unpack_from("<i", data, 0)[0]


def _field(data: bytes, table: int, slot: int) -> int:
    vt = table - struct.unpack_from("<i", data, table)[0]
    vsize = struct.unpack_from("<H", data, vt)[0]
    entry = 4 + slot * 2
    if entry + 2 > vsize:
        return 0
    return struct.unpack_from("<H", data, vt + entry)[0]


def _i32(data: bytes, table: int, slot: int) -> int:
    off = _field(data, table, slot)
    if not off:
        return 0
    return struct.unpack_from("<i", data, table + off)[0]


def _i64_slot(data: bytes, table: int, slot: int) -> int:
    off = _field(data, table, slot)
    if not off:
        return 0
    return struct.unpack_from("<q", data, table + off)[0]


def _f32_slot(data: bytes, table: int, slot: int) -> float:
    off = _field(data, table, slot)
    if not off:
        return 0.0
    return struct.unpack_from("<f", data, table + off)[0]


def _string(data: bytes, table: int, slot: int) -> str:
    off = _field(data, table, slot)
    if not off:
        return ""
    rel = struct.unpack_from("<I", data, table + off)[0]
    addr = table + off + rel
    n = struct.unpack_from("<I", data, addr)[0]
    return data[addr + 4 : addr + 4 + n].decode("utf-8")


def _vector(data: bytes, table: int, slot: int, width: int, code: str, *, copy: bool) -> Any:
    off = _field(data, table, slot)
    if not off:
        return [] if copy else memoryview(b"").cast(code)
    rel = struct.unpack_from("<I", data, table + off)[0]
    addr = table + off + rel
    n = struct.unpack_from("<I", data, addr)[0]
    start = addr + 4
    if copy:
        if code == "f":
            return list(struct.unpack_from(f"<{n}f", data, start))
        return list(struct.unpack_from(f"<{n}q", data, start))
    view = memoryview(data)[start : start + n * width]
    return view.cast(code)


def _fb_read_prompt(
    data: bytes,
    table: int,
    *,
    batch_slot: int = 0,
    seq_slot: int = 1,
    ids: int = 2,
    mask: int = 3,
    pos: int = 4,
) -> Prompt:
    return Prompt(
        batch=_i32(data, table, batch_slot),
        seq=_i32(data, table, seq_slot),
        input_ids=_vector(data, table, ids, 8, "q", copy=True),
        attention_mask=_vector(data, table, mask, 8, "q", copy=True),
        position_ids=_vector(data, table, pos, 8, "q", copy=True),
    )
