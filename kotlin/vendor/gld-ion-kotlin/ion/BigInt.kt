package ion

import java.math.BigInteger

/**
 * Sign-and-magnitude integer. Limbs are little-endian base 2^32.
 * An empty limb list is zero, and zero is never negative.
 */
class BigInt(var neg: Boolean = false) {
    val limbs = ArrayList<Int>(2)

    fun isZero(): Boolean = limbs.isEmpty()

    fun trim() {
        while (limbs.isNotEmpty() && limbs.last() == 0) {
            limbs.removeAt(limbs.lastIndex)
        }
        if (limbs.isEmpty()) neg = false
    }

    fun cmpMag(other: BigInt): Int {
        if (limbs.size != other.limbs.size) {
            return if (limbs.size < other.limbs.size) -1 else 1
        }
        var i = limbs.size - 1
        while (i >= 0) {
            val a = u32(limbs[i])
            val b = u32(other.limbs[i])
            if (a < b) return -1
            if (a > b) return 1
            i--
        }
        return 0
    }

    fun toBigInteger(): BigInteger {
        val be = toBeBytes()
        val mag = if (be.isEmpty()) BigInteger.ZERO else BigInteger(1, be)
        return if (neg) mag.negate() else mag
    }

    fun magDecimal(): String {
        if (isZero()) return "0"
        return toBigInteger().abs().toString()
    }

    fun toI64(offset: Int): Long {
        if (limbs.size > 2) throw DecodeError(DecodeError.KIND_RANGE, offset)
        var mag = 0L
        if (limbs.isNotEmpty()) mag = u32(limbs[0])
        if (limbs.size > 1) mag = mag or (u32(limbs[1]) shl 32)
        if (!neg) {
            if (mag < 0L) throw DecodeError(DecodeError.KIND_RANGE, offset)
            return mag
        }
        if (mag == Long.MIN_VALUE) return Long.MIN_VALUE
        if (mag < 0L) throw DecodeError(DecodeError.KIND_RANGE, offset)
        return -mag
    }

    /** Unsigned big-endian magnitude with no leading zero byte. Zero is empty. */
    fun toBeBytes(): ByteArray {
        if (limbs.isEmpty()) return ByteArray(0)
        val out = ByteBuf(limbs.size * 4)
        var started = false
        var i = limbs.size - 1
        while (i >= 0) {
            val limb = u32(limbs[i])
            var shift = 24
            while (shift >= 0) {
                val b = ((limb shr shift) and 0xFF).toInt()
                if (started || b != 0) {
                    started = true
                    out.add(b)
                }
                shift -= 8
            }
            i--
        }
        return out.toByteArray()
    }
}

internal fun bigFromU64(v: Long, neg: Boolean): BigInt {
    val lo = (v and 0xFFFFFFFFL).toInt()
    val hi = (v ushr 32).toInt()
    val b = BigInt()
    if (lo != 0 || hi != 0) b.limbs.add(lo)
    if (hi != 0) b.limbs.add(hi)
    b.neg = neg && !b.isZero()
    return b
}

internal fun bigFromDigits(digits: ByteArray, neg: Boolean): BigInt {
    var i = 0
    while (i < digits.size && digits[i] == '0'.code.toByte()) i++
    if (i == digits.size) return BigInt()
    val s = String(digits, i, digits.size - i, Charsets.US_ASCII)
    val bi = BigInteger(s)
    return bigFromInteger(if (neg) bi.negate() else bi)
}

internal fun bigFromRadix(text: String, radix: Int, neg: Boolean): BigInt {
    if (text.isEmpty()) return BigInt()
    val bi = BigInteger(text, radix)
    if (bi.signum() == 0) return BigInt()
    return bigFromInteger(if (neg) bi.negate() else bi)
}

internal fun bigFromBe(raw: ByteArray, neg: Boolean, offset: Int): BigInt {
    var start = 0
    while (start < raw.size && raw[start] == 0.toByte()) start++
    if (start == raw.size) return BigInt()
    if (raw.size - start > 1_048_576) throw DecodeError(DecodeError.KIND_RANGE, offset)
    val slice = if (start == 0) raw else raw.copyOfRange(start, raw.size)
    val bi = BigInteger(1, slice)
    return bigFromInteger(if (neg) bi.negate() else bi)
}

internal fun bigFromInteger(v: BigInteger): BigInt {
    if (v.signum() == 0) return BigInt()
    val neg = v.signum() < 0
    val be = v.abs().toByteArray()
    val b = BigInt(neg)
    b.limbs.addAll(limbsFromBe(be))
    b.trim()
    b.neg = neg && !b.isZero()
    return b
}

private fun limbsFromBe(be: ByteArray): ArrayList<Int> {
    var start = 0
    while (start < be.size && be[start] == 0.toByte()) start++
    val limbs = ArrayList<Int>()
    var pos = be.size
    while (pos > start) {
        val take = minOf(4, pos - start)
        var chunk = 0
        var k = 0
        while (k < take) {
            chunk = (chunk shl 8) or (be[pos - take + k].toInt() and 0xFF)
            k++
        }
        limbs.add(chunk)
        pos -= take
    }
    return limbs
}

internal fun fracGeOne(coef: BigInt, exp: Long): Boolean {
    if (coef.isZero()) return false
    if (exp >= 0) return true
    if (exp == Long.MIN_VALUE) return false
    val k = -exp
    if (k > Int.MAX_VALUE) return false
    val digits = coef.magDecimal().length
    return digits > k.toInt()
}
