# IEEE 754 binary16 <-> binary64 helpers. No C math library.

def half_to_f64(bits: UInt16) -> Float64:
    var s = UInt64(bits >> UInt16(15))
    var exp = Int((bits >> UInt16(10)) & UInt16(0x1F))
    var frac = UInt64(bits & UInt16(0x3FF))
    var sign = s << UInt64(63)
    if exp == 0:
        if frac == UInt64(0):
            return Float64(from_bits=sign)
        # subnormal: value = 2^-14 * frac / 1024
        var f = Float64(Int(frac)) / 1024.0
        var mag = f / 16384.0
        if s == UInt64(1):
            return -mag
        return mag
    if exp == 31:
        var out_exp = UInt64(0x7FF) << UInt64(52)
        var out_frac = frac << UInt64(42)
        return Float64(from_bits=sign | out_exp | out_frac)
    var out_e = UInt64(exp + 1023 - 15) << UInt64(52)
    var out_f = frac << UInt64(42)
    return Float64(from_bits=sign | out_e | out_f)


def f64_to_half_bits(v: Float64) -> UInt16:
    var bits = UInt64(v.to_bits())
    var sign = UInt16((bits >> UInt64(63)) & UInt64(1)) << UInt16(15)
    var exp = Int((bits >> UInt64(52)) & UInt64(0x7FF))
    var frac = bits & ((UInt64(1) << UInt64(52)) - UInt64(1))
    if exp == 0x7FF:
        var nan_frac = UInt16(0)
        if frac != UInt64(0):
            nan_frac = UInt16(0x200) | UInt16((frac >> UInt64(42)) & UInt64(0x3FF))
            if nan_frac == UInt16(0):
                nan_frac = UInt16(0x200)
        return sign | UInt16(0x7C00) | nan_frac
    var unbiased = exp - 1023
    if exp == 0 or unbiased < -24:
        return sign
    if unbiased > 15:
        return sign | UInt16(0x7C00)
    if unbiased >= -14:
        var he = UInt16(unbiased + 15)
        var hf = UInt16((frac >> UInt64(42)) & UInt64(0x3FF))
        return sign | (he << UInt16(10)) | hf
    # subnormal
    var shift = UInt64(14 - unbiased)
    var mant = (UInt64(1) << UInt64(52)) | frac
    var hf2 = UInt16((mant >> (UInt64(42) + shift - UInt64(1))) & UInt64(0x3FF))
    return sign | hf2


def f32_from_bits(bits: UInt32) -> Float32:
    return Float32(from_bits=bits)


def f32_to_bits(v: Float32) -> UInt32:
    return UInt32(v.to_bits())


def f64_from_bits(bits: UInt64) -> Float64:
    return Float64(from_bits=bits)


def f64_to_bits(v: Float64) -> UInt64:
    return UInt64(v.to_bits())
