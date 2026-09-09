comptime MAX_DEPTH = 100
comptime MAX_ITEM_BYTES = 64_194_304
comptime MAX_COUNT = 1_048_576


def is_ws(c: Int) -> Bool:
    return c == 32 or c == 9 or c == 10 or c == 13


def is_digit(c: Int) -> Bool:
    return c >= 48 and c <= 57


def hex_digit(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 97 and c <= 102:
        return c - 87
    if c >= 65 and c <= 70:
        return c - 55
    return -1
