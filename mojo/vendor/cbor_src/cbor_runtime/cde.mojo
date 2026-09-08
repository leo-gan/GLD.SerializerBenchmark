from std.collections import List, Span

from cbor_runtime.error import DecodeError


def encoded_lt(a: List[Byte], b: List[Byte]) -> Bool:
    """RFC 8949 §4.2.1: compare two encoded keys as unsigned byte strings."""
    var n = len(a)
    if len(b) < n:
        n = len(b)
    for i in range(n):
        if Int(a[i]) < Int(b[i]):
            return True
        if Int(a[i]) > Int(b[i]):
            return False
    return len(a) < len(b)


def encoded_eq(a: List[Byte], b: List[Byte]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if Int(a[i]) != Int(b[i]):
            return False
    return True


def sort_by_encoded_keys(keys: List[List[Byte]]) -> List[Int]:
    """Permutation that orders map pairs by encoded key bytes (CDE)."""
    var order = List[Int]()
    var pairs = len(keys)
    for i in range(pairs):
        order.append(i)
    for i in range(pairs):
        var j = i
        while j > 0:
            if encoded_lt(keys[order[j]], keys[order[j - 1]]):
                var tmp = order[j]
                order[j] = order[j - 1]
                order[j - 1] = tmp
                j -= 1
            else:
                break
    return order^


def assert_cde_roundtrip[
    origin: ImmOrigin
](original: Span[Byte, origin], rewritten: List[Byte]) raises DecodeError:
    """Used by `decode_strict`: the CDE rewrite must match the input bytes."""
    if len(rewritten) != len(original):
        raise DecodeError(DecodeError.KIND_CDE, 0)
    for i in range(len(original)):
        if Int(rewritten[i]) != Int(original[i]):
            raise DecodeError(DecodeError.KIND_CDE, i)
