from std.collections import List
from std.os import getenv


def strategy() -> String:
    var env = String(getenv("BENCHMARK_SCHEDULE"))
    if env == "none":
        return "none"
    return "block_shuffle"


def record_run_order() -> Bool:
    var env = String(getenv("BENCHMARK_RECORD_RUN_ORDER"))
    if env.byte_length() == 0:
        return True
    return env != "0" and env != "false"


def _mix(h: Int, s: String) -> Int:
    var b = s.as_bytes()
    var i = 0
    var out = h
    while i < len(b):
        out = ((out ^ Int(b[i])) * 16777619) & 0x7FFFFFFF
        i += 1
    return out


def shuffle(
    names: List[String], seed: Int, type_id: String, n: Int, hash: String, mode: String, rep: Int
) -> List[String]:
    var h = seed
    h = _mix(h, type_id)
    h = _mix(h, String(n))
    h = _mix(h, hash)
    h = _mix(h, mode)
    h = _mix(h, String(rep))
    var rng = h & 0x7FFFFFFF
    if rng == 0:
        rng = 1
    var out = List[String]()
    var i = 0
    while i < len(names):
        out.append(names[i])
        i += 1
    var count = len(out)
    i = count - 1
    while i > 0:
        rng = (rng * 1103515245 + 12345) & 0x7FFFFFFF
        var j = rng % (i + 1)
        var tmp = out[i]
        out[i] = out[j]
        out[j] = tmp
        i -= 1
    return out^
