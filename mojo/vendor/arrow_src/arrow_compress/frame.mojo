from std.collections import List

from arrow_compress.lz4 import lz4_frame_compress, lz4_frame_decompress
from arrow_compress.zstd import zstd_compress, zstd_decompress
from arrow_runtime.error import DecodeError


def frame_compress(codec: Int, raw: List[Byte]) raises DecodeError -> List[Byte]:
    if codec == 0:
        return lz4_frame_compress(raw)
    if codec == 1:
        return zstd_compress(raw)
    raise DecodeError(DecodeError.KIND_COMPRESSION, codec)


def frame_decompress(codec: Int, raw: List[Byte]) raises DecodeError -> List[Byte]:
    if codec == 0:
        return lz4_frame_decompress(raw)
    if codec == 1:
        return zstd_decompress(raw)
    raise DecodeError(DecodeError.KIND_COMPRESSION, codec)
