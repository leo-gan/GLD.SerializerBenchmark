from gldjson_runtime.options import EncodeOptions
from gldjson_wire.writer import WireWriter


def sep_len(options: EncodeOptions, first: Bool, depth: Int) -> Int:
    if options.mode != EncodeOptions.PRETTY:
        if first:
            return 0
        return 1
    var n = 1 + (depth + 1) * options.indent
    if not first:
        n += 1
    return n


def close_len(options: EncodeOptions, depth: Int) -> Int:
    if options.mode != EncodeOptions.PRETTY:
        return 1
    return 2 + depth * options.indent
