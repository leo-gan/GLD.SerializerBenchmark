# Branchless 64-bit prefix-XOR and escape-mask helpers for stage 1.
#
# These are the building blocks that turn the per-chunk escape-state
# machine and "is byte i inside a JSON string?" question into pure
# bit-twiddling on 64-bit masks: a fixed number of ALU ops
# independent of chunk content instead of a byte-by-byte scalar walk.
#
# prefix_xor64 ---------------------------------------------------------------
#
# For bit i of the result: XOR of bits 0..i of the input. This is the
# Hillis-Steele scan over GF(2) that turns the "find unescaped quote
# pairs to compute string boundaries" task into one branchless 64-bit
# operation. simdjson C++ uses CLMUL by an all-ones constant for this
# (one cycle on Skylake/Zen3 with PCLMULQDQ); we use the equivalent
# six-shift software implementation. On modern CPUs both forms run in
# under 10 cycles, well below memory bandwidth, and the software form
# has zero ISA dependencies and zero feature-detection overhead.
#
# find_escape_mask64 ---------------------------------------------------------
#
# Given a 64-bit "is this byte a backslash?" mask plus the carry bit
# from the previous chunk, returns:
#   - escape_mask:        bit i set iff byte i is escaped (i.e. it is
#                         the byte after an odd-length backslash run).
#   - new_carry:          1 iff byte 0 of the NEXT chunk is escaped by
#                         a backslash that lives at byte 63 of this
#                         chunk (the only way a pending escape can
#                         straddle a 64-byte boundary).
#
# Algorithm follows simdjson's branchless `find_escaped` (json_escape_
# scanner.h). The maths:
#
#   1. Strip out backslashes that are themselves escaped by the
#      pending-from-prev-chunk byte.
#   2. `follows_escape` marks every byte that immediately follows an
#      unescaped backslash -- escape-candidate positions.
#   3. Even/odd-position bit masks isolate runs starting at bit
#      positions of each parity. A run of length L starting at parity P
#      ends with an escape on the byte after the run iff (L is odd).
#   4. `bslash + odd_sequence_starts` propagates carries through
#      contiguous backslash runs; the overflow bit becomes the next
#      chunk's `prev_escape`.
#   5. XOR the addition's sum with `bslash` itself to invert exactly
#      the bits that belong to runs of inverted parity, then AND with
#      `follows_escape` to keep only positions that actually follow a
#      backslash.

from std.sys.intrinsics import llvm_intrinsic


# ---------------------------------------------------------------------------
# Software prefix-XOR (six shifts).
# ---------------------------------------------------------------------------


@always_inline("nodebug")
def prefix_xor64(x: UInt64) -> UInt64:
    """Per-bit prefix XOR over 64 bits.

    Equivalent to `clmul(x, ~UInt64(0)).low_64()` (one PCLMULQDQ on x86
    or one PMULL on ARM64 with CLMUL). The shift-based form below
    compiles to six `xor`+`shl` pairs, ~6 cycles on a modern OoO core
    -- well within the per-chunk budget for 64-byte stage 1 work
    units, and free of any ISA feature gating.
    """
    var r = x
    r ^= r << 1
    r ^= r << 2
    r ^= r << 4
    r ^= r << 8
    r ^= r << 16
    r ^= r << 32
    return r


# ---------------------------------------------------------------------------
# Branchless escape-mask scanner (simdjson-style).
#
# Inlines the wrapping-add-with-carry detection (the only place we need
# it). LLVM lowers `sum < a` after `sum = a + b` (wraparound semantics
# for unsigned types) to the same `adcs` / `adc` instruction that
# `llvm.uadd.with.overflow.i64` would have emitted, so there's no
# cycle to gain by reaching for the intrinsic.
# ---------------------------------------------------------------------------


@always_inline
def find_escape_mask64(backslash: UInt64, mut prev_escape: UInt64) -> UInt64:
    """Returns the bit-mask of bytes that are escaped within this chunk.

    `prev_escape` carries the "byte 0 of this chunk is escaped by a
    backslash from the previous chunk" flag (0 or 1). After the call,
    `prev_escape` is updated to be the carry into the NEXT chunk -- 1
    iff this chunk ended with a backslash whose escape lands on byte 0
    of the chunk after.

    Mirrors simdjson's `json_escape_scanner::next`.
    """
    if backslash == 0:
        var escaped = prev_escape
        prev_escape = 0
        return escaped

    # Save the carry-in bit before we consume it -- the algorithm
    # below uses `prev_escape` in `follows_escape`, but the parity
    # mask `(~EVEN_BITS ^ invert_mask)` zeros bit 0 (because 0 is even
    # and bit 0 of `bslash` was cleared by step (1)). We OR
    # `incoming_escape` back into the final mask so that a backslash
    # straddling the previous chunk boundary still escapes byte 0.
    var incoming_escape = prev_escape

    # (1) Backslashes already escaped by the prior chunk's pending
    #     escape don't themselves start a new run.
    var bslash = backslash & ~prev_escape

    # (2) Bytes that immediately follow an unescaped backslash --
    #     these are the only bytes that can ever be escaped.
    var follows_escape = (bslash << 1) | prev_escape

    # (3) Starts of backslash runs at odd bit positions. Even bits of
    #     `0x5555...` are bits 0, 2, 4, ...; the complement is the odd
    #     bits 1, 3, 5, ...
    comptime EVEN_BITS: UInt64 = 0x5555555555555555
    var odd_sequence_starts = bslash & ~EVEN_BITS & ~follows_escape

    # (4) Adding `bslash` propagates a carry through every contiguous
    #     run starting at an odd-parity bit; the overflow bit becomes
    #     the carry into the next chunk.
    var sum = odd_sequence_starts + bslash
    prev_escape = UInt64(1) if sum < odd_sequence_starts else UInt64(0)

    # (5) Mask of bits that ended up in a "flipped" run -- XOR the sum
    #     with bslash, then XOR with the ODD-position constant
    #     (~EVEN_BITS) so the result is `1` on positions that are the
    #     escape target of an odd-length run. AND with follows_escape
    #     to drop bits that don't actually trail a backslash.
    var invert_mask = sum ^ bslash
    var escape_mask = (~EVEN_BITS ^ invert_mask) & follows_escape
    return escape_mask | incoming_escape
