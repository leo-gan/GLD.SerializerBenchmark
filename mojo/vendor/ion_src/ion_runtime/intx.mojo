from std.collections import List, Span

from ion_runtime.error import DecodeError


comptime LIMB = 32
comptime LIMB_MASK = UInt64(0xFFFFFFFF)


struct BigInt(Movable):
    """Sign-and-magnitude integer. Limbs are little-endian base 2^32. An empty limb list is zero."""

    var neg: Bool
    var limbs: List[UInt32]

    def __init__(out self):
        self.neg = False
        self.limbs = List[UInt32]()

    def __init__(out self, neg: Bool, var limbs: List[UInt32]):
        self.neg = neg
        self.limbs = limbs^
        self._trim()
        if len(self.limbs) == 0:
            self.neg = False

    def is_zero(self) -> Bool:
        return len(self.limbs) == 0

    def _trim(mut self):
        while len(self.limbs) > 0 and self.limbs[len(self.limbs) - 1] == UInt32(0):
            _ = self.limbs.pop()

    def bit_length(self) -> Int:
        if len(self.limbs) == 0:
            return 0
        var top = self.limbs[len(self.limbs) - 1]
        var bits = (len(self.limbs) - 1) * LIMB
        var v = UInt32(top)
        while v > UInt32(0):
            bits += 1
            v = v >> UInt32(1)
        return bits

    def cmp_mag(self, other: Self) -> Int:
        if len(self.limbs) != len(other.limbs):
            if len(self.limbs) < len(other.limbs):
                return -1
            return 1
        var i = len(self.limbs) - 1
        while i >= 0:
            if self.limbs[i] < other.limbs[i]:
                return -1
            if self.limbs[i] > other.limbs[i]:
                return 1
            i -= 1
        return 0

    def eq_mag(self, other: Self) -> Bool:
        return self.cmp_mag(other) == 0

    def to_i64(self, offset: Int) raises DecodeError -> Int64:
        if len(self.limbs) > 2:
            raise DecodeError(DecodeError.KIND_RANGE, offset)
        var mag = UInt64(0)
        if len(self.limbs) > 0:
            mag = UInt64(self.limbs[0])
        if len(self.limbs) > 1:
            mag = mag | (UInt64(self.limbs[1]) << UInt64(32))
        if not self.neg:
            if mag > UInt64(0x7FFFFFFFFFFFFFFF):
                raise DecodeError(DecodeError.KIND_RANGE, offset)
            return Int64(mag)
        if mag > UInt64(0x8000000000000000):
            raise DecodeError(DecodeError.KIND_RANGE, offset)
        if mag == UInt64(0x8000000000000000):
            return Int64(-9223372036854775807) - Int64(1)
        return Int64(0) - Int64(mag)

    def to_dec(self) -> String:
        var raw = self.to_dec_bytes()
        return String(unsafe_from_utf8=raw)

    def to_dec_bytes(self) -> List[Byte]:
        var digits = List[Byte]()
        if len(self.limbs) == 0:
            digits.append(Byte(48))
            return digits^
        var scratch = List[UInt32]()
        var i = 0
        while i < len(self.limbs):
            scratch.append(self.limbs[i])
            i += 1
        while len(scratch) > 0:
            var rem = UInt64(0)
            var j = len(scratch) - 1
            while j >= 0:
                var cur = (rem << UInt64(32)) | UInt64(scratch[j])
                scratch[j] = UInt32(cur / UInt64(10))
                rem = cur % UInt64(10)
                j -= 1
            digits.append(Byte(Int(rem) + 48))
            while len(scratch) > 0 and scratch[len(scratch) - 1] == UInt32(0):
                _ = scratch.pop()
        var out = List[Byte]()
        if self.neg:
            out.append(Byte(45))
        var k = len(digits) - 1
        while k >= 0:
            out.append(digits[k])
            k -= 1
        return out^

    def mul_small(mut self, m: UInt32):
        if m == UInt32(0) or len(self.limbs) == 0:
            self.limbs.clear()
            self.neg = False
            return
        var carry = UInt64(0)
        var i = 0
        while i < len(self.limbs):
            var cur = UInt64(self.limbs[i]) * UInt64(m) + carry
            self.limbs[i] = UInt32(cur & LIMB_MASK)
            carry = cur >> UInt64(32)
            i += 1
        if carry != UInt64(0):
            self.limbs.append(UInt32(carry))

    def add_small(mut self, m: UInt32):
        var carry = UInt64(m)
        var i = 0
        while carry != UInt64(0):
            if i == len(self.limbs):
                self.limbs.append(UInt32(carry))
                return
            var cur = UInt64(self.limbs[i]) + carry
            self.limbs[i] = UInt32(cur & LIMB_MASK)
            carry = cur >> UInt64(32)
            i += 1

    def to_be_bytes(self) -> List[Byte]:
        """Unsigned big-endian magnitude, with no leading zero byte. Zero is an empty list."""
        var out = List[Byte]()
        if len(self.limbs) == 0:
            return out^
        var started = False
        var i = len(self.limbs) - 1
        while i >= 0:
            var limb = self.limbs[i]
            var shift = 24
            while shift >= 0:
                var b = Byte((Int(limb) >> shift) & 0xFF)
                if started or Int(b) != 0:
                    started = True
                    out.append(b)
                shift -= 8
            i -= 1
        return out^


def big_from_u64(v: UInt64, neg: Bool) -> BigInt:
    var limbs = List[UInt32]()
    var lo = UInt32(v & LIMB_MASK)
    var hi = UInt32(v >> UInt64(32))
    if lo != UInt32(0) or hi != UInt32(0):
        limbs.append(lo)
    if hi != UInt32(0):
        limbs.append(hi)
    var use_neg = neg and (lo != UInt32(0) or hi != UInt32(0))
    return BigInt(use_neg, limbs^)


def big_from_digit_list(digits: List[Byte], neg: Bool) -> BigInt:
    var acc = BigInt()
    var i = 0
    var seen = False
    while i < len(digits):
        var d = Int(digits[i]) - 48
        if not seen and d == 0:
            i += 1
            continue
        seen = True
        acc.mul_small(UInt32(10))
        acc.add_small(UInt32(d))
        i += 1
    if len(acc.limbs) != 0:
        acc.neg = neg
    return acc^


def big_from_digits[origin: ImmOrigin](digits: Span[Byte, origin], neg: Bool) -> BigInt:
    """`digits` holds ASCII `0`–`9`. Leading zeros are ignored, so an all-zero span is zero."""
    var acc = BigInt()
    var i = 0
    var seen = False
    while i < len(digits):
        var d = Int(digits[i]) - 48
        if not seen and d == 0:
            i += 1
            continue
        seen = True
        acc.mul_small(UInt32(10))
        acc.add_small(UInt32(d))
        i += 1
    if len(acc.limbs) != 0:
        acc.neg = neg
    return acc^


def big_from_be[origin: ImmOrigin](raw: Span[Byte, origin], neg: Bool, offset: Int) raises DecodeError -> BigInt:
    """Big-endian magnitude. Leading zero bytes do not change the value."""
    var start = 0
    while start < len(raw) and Int(raw[start]) == 0:
        start += 1
    if start == len(raw):
        return BigInt()
    if len(raw) - start > 1_048_576:
        raise DecodeError(DecodeError.KIND_RANGE, offset)
    var limbs = List[UInt32]()
    var pos = len(raw)
    while pos > start:
        var take = pos - start
        if take > 4:
            take = 4
        var chunk = UInt32(0)
        var k = 0
        while k < take:
            chunk = (chunk << UInt32(8)) | UInt32(Int(raw[pos - take + k]))
            k += 1
        limbs.append(chunk)
        pos -= take
    return BigInt(neg, limbs^)
