from std.collections import List, Span

from cbor_runtime.error import DecodeError


struct _Re(Movable):
    var pat: List[Byte]
    var text: List[Byte]
    var cap_s: List[Int]
    var cap_e: List[Int]

    def __init__(out self, var pat: List[Byte], var text: List[Byte]):
        self.pat = pat^
        self.text = text^
        self.cap_s = List[Int]()
        self.cap_e = List[Int]()
        for _i in range(10):
            self.cap_s.append(-1)
            self.cap_e.append(-1)

    def _at(self, i: Int) -> Int:
        if i >= len(self.pat):
            return -1
        return Int(self.pat[i])

    def _txt(self, i: Int) -> Int:
        if i >= len(self.text):
            return -1
        return Int(self.text[i])


def _is_word(c: Int) -> Bool:
    if c >= 48 and c <= 57:
        return True
    if c >= 65 and c <= 90:
        return True
    if c >= 97 and c <= 122:
        return True
    return c == 95


def _is_space(c: Int) -> Bool:
    return c == 32 or c == 9 or c == 10 or c == 13


def _hex(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 97 and c <= 102:
        return c - 87
    if c >= 65 and c <= 70:
        return c - 55
    return -1


def _escape(re: _Re, pp: Int) raises DecodeError -> Tuple[Int, Int]:
    # class: -2=\d -3=\w -4=\s -6=\D -7=\W -8=\S -9=\b -11=\B; -20-n = backref n
    if pp >= len(re.pat):
        raise DecodeError(DecodeError.KIND_CDDL, pp)
    var e = re._at(pp)
    if e == 100:  # d
        return (-2, pp + 1)
    if e == 68:  # D
        return (-6, pp + 1)
    if e == 119:  # w
        return (-3, pp + 1)
    if e == 87:  # W
        return (-7, pp + 1)
    if e == 115:  # s
        return (-4, pp + 1)
    if e == 83:  # S
        return (-8, pp + 1)
    if e == 98:  # b
        return (-9, pp + 1)
    if e == 66:  # B
        return (-11, pp + 1)
    if e >= 49 and e <= 57:
        return (-20 - (e - 48), pp + 1)
    if e == 110:  # n
        return (10, pp + 1)
    if e == 116:  # t
        return (9, pp + 1)
    if e == 114:  # r
        return (13, pp + 1)
    return (e, pp + 1)


def _group_kind(re: _Re, pp: Int) -> Tuple[Int, Int]:
    # 0 capturing, 1 (?: 2 (?= 3 (?! 4 (?<= 5 (?<!
    if re._at(pp + 1) != 63:
        return (0, pp + 1)
    var c = re._at(pp + 2)
    if c == 58:
        return (1, pp + 3)
    if c == 61:
        return (2, pp + 3)
    if c == 33:
        return (3, pp + 3)
    if c == 60:
        var d = re._at(pp + 3)
        if d == 61:
            return (4, pp + 4)
        if d == 33:
            return (5, pp + 4)
    return (0, pp + 1)


def _capturing_index(re: _Re, pp: Int) -> Int:
    var n = 0
    var i = 0
    while i <= pp:
        if re._at(i) == 40:
            var k = _group_kind(re, i)
            if k[0] == 0:
                n += 1
            if i == pp:
                return n
            i = k[1]
            continue
        if re._at(i) == 92:
            i += 2
            continue
        i += 1
    return n


def _class_match(re: _Re, pp: Int, ch: Int) raises DecodeError -> Tuple[Bool, Int]:
    # pp points just after '['
    var p = pp
    var neg = False
    if re._at(p) == 94:
        neg = True
        p += 1
    var ok = False
    if re._at(p) == -1:
        raise DecodeError(DecodeError.KIND_CDDL, p)
    while re._at(p) != 93 and re._at(p) != -1:
        var a: Int
        if re._at(p) == 92:
            var es = _escape(re, p + 1)
            a = es[0]
            p = es[1]
            if a == -2:
                if ch >= 48 and ch <= 57:
                    ok = True
                continue
            if a == -6:
                if ch < 48 or ch > 57:
                    ok = True
                continue
            if a == -3:
                if _is_word(ch):
                    ok = True
                continue
            if a == -7:
                if not _is_word(ch):
                    ok = True
                continue
            if a == -4:
                if _is_space(ch):
                    ok = True
                continue
            if a == -8:
                if not _is_space(ch):
                    ok = True
                continue
        else:
            a = re._at(p)
            p += 1
        if re._at(p) == 45 and re._at(p + 1) != 93 and re._at(p + 1) != -1:
            p += 1
            var b = re._at(p)
            if b == 92:
                var es2 = _escape(re, p + 1)
                b = es2[0]
                p = es2[1]
            else:
                p += 1
            if ch >= a and ch <= b:
                ok = True
        else:
            if ch == a:
                ok = True
    if re._at(p) != 93:
        raise DecodeError(DecodeError.KIND_CDDL, p)
    if neg:
        ok = not ok
    return (ok, p + 1)


def _match_atom(mut re: _Re, pp: Int, tp: Int) raises DecodeError -> Tuple[Bool, Int, Int]:
    var c = re._at(pp)
    if c == -1:
        return (True, pp, tp)
    if c == 94:  # ^
        return (tp == 0, pp + 1, tp)
    if c == 36:  # $
        return (tp == len(re.text), pp + 1, tp)
    if c == 46:  # .
        if tp >= len(re.text):
            return (False, pp, tp)
        return (True, pp + 1, tp + 1)
    if c == 92:
        var es = _escape(re, pp + 1)
        var code = es[0]
        var np = es[1]
        if code == -9 or code == -11:
            var prev_w = tp > 0 and _is_word(re._txt(tp - 1))
            var next_w = tp < len(re.text) and _is_word(re._txt(tp))
            var boundary = prev_w != next_w
            if code == -9:
                return (boundary, np, tp)
            return (not boundary, np, tp)
        if code <= -21:
            var gi = -code - 20
            if gi < 1 or gi > 9 or re.cap_s[gi] < 0:
                return (False, pp, tp)
            var a = re.cap_s[gi]
            var b = re.cap_e[gi]
            var k = 0
            while a + k < b:
                if tp + k >= len(re.text) or re._txt(tp + k) != re._txt(a + k):
                    return (False, pp, tp)
                k += 1
            return (True, np, tp + k)
        if tp >= len(re.text):
            return (False, pp, tp)
        var ch = re._txt(tp)
        var ok = False
        if code == -2:
            ok = ch >= 48 and ch <= 57
        elif code == -6:
            ok = ch < 48 or ch > 57
        elif code == -3:
            ok = _is_word(ch)
        elif code == -7:
            ok = not _is_word(ch)
        elif code == -4:
            ok = _is_space(ch)
        elif code == -8:
            ok = not _is_space(ch)
        else:
            ok = ch == code
        if not ok:
            return (False, pp, tp)
        return (True, np, tp + 1)
    if c == 91:
        if tp >= len(re.text):
            return (False, pp, tp)
        var cm = _class_match(re, pp + 1, re._txt(tp))
        if not cm[0]:
            return (False, pp, tp)
        return (True, cm[1], tp + 1)
    if c == 40:
        var kind = _group_kind(re, pp)
        var body = kind[1]
        if kind[0] == 1:
            # (?:...)
            var inner = _match_expr(re, body, tp)
            if not inner[0] or re._at(inner[1]) != 41:
                return (False, pp, tp)
            return (True, inner[1] + 1, inner[2])
        if kind[0] == 2 or kind[0] == 3:
            var inner2 = _match_expr(re, body, tp)
            var matched = inner2[0] and re._at(inner2[1]) == 41
            var ok2 = matched
            if kind[0] == 3:
                ok2 = not matched
            var endp = _atom_end(re, pp)
            if not ok2:
                return (False, pp, tp)
            return (True, endp, tp)
        if kind[0] == 4 or kind[0] == 5:
            var endp2 = _atom_end(re, pp)
            var found = False
            var s = 0
            while s <= tp:
                var m = _match_expr(re, body, s)
                if m[0] and m[2] == tp and re._at(m[1]) == 41:
                    found = True
                    break
                s += 1
            if kind[0] == 5:
                found = not found
            if not found:
                return (False, pp, tp)
            return (True, endp2, tp)
        var g = _capturing_index(re, pp)
        var inner3 = _match_expr(re, body, tp)
        if not inner3[0] or re._at(inner3[1]) != 41:
            return (False, pp, tp)
        if g >= 1 and g <= 9:
            re.cap_s[g] = tp
            re.cap_e[g] = inner3[2]
        return (True, inner3[1] + 1, inner3[2])
    if tp >= len(re.text) or re._txt(tp) != c:
        return (False, pp, tp)
    return (True, pp + 1, tp + 1)


def _quant(re: _Re, pp: Int) -> Tuple[Int, Int, Int]:
    # returns (min, max, new_pp) max -1 = inf
    var c = re._at(pp)
    if c == 42:
        return (0, -1, pp + 1)
    if c == 43:
        return (1, -1, pp + 1)
    if c == 63:
        return (0, 1, pp + 1)
    if c == 123:
        var p = pp + 1
        var mn = 0
        var digits = False
        while re._at(p) >= 48 and re._at(p) <= 57:
            mn = mn * 10 + (re._at(p) - 48)
            p += 1
            digits = True
        if not digits:
            return (1, 1, pp)
        if re._at(p) == 125:
            return (mn, mn, p + 1)
        if re._at(p) != 44:
            return (1, 1, pp)
        p += 1
        if re._at(p) == 125:
            return (mn, -1, p + 1)
        var mx = 0
        var d2 = False
        while re._at(p) >= 48 and re._at(p) <= 57:
            mx = mx * 10 + (re._at(p) - 48)
            p += 1
            d2 = True
        if d2 and re._at(p) == 125:
            return (mn, mx, p + 1)
        return (1, 1, pp)
    return (1, 1, pp)


def _factor_ends(mut re: _Re, pp: Int, tp: Int) raises DecodeError -> Tuple[Int, List[Int]]:
    """Return (pattern_after_factor, text positions after 0..n greedy matches)."""
    var atom_end = _atom_end(re, pp)
    var q = _quant(re, atom_end)
    var mn = q[0]
    var mx = q[1]
    var after = q[2]
    var pos = List[Int]()
    var cur = tp
    var count = 0
    if mn == 0:
        pos.append(cur)
    while mx < 0 or count < mx:
        var one = _match_atom(re, pp, cur)
        if not one[0]:
            break
        if one[2] == cur:
            count += 1
            if count >= mn:
                pos.append(cur)
            break
        cur = one[2]
        count += 1
        if count >= mn:
            pos.append(cur)
    return (after, pos^)


def _atom_end(re: _Re, pp: Int) raises DecodeError -> Int:
    var c = re._at(pp)
    if c == 92:
        return _escape(re, pp + 1)[1]
    if c == 91:
        var i = pp + 1
        if re._at(i) == 94:
            i += 1
        while re._at(i) != 93 and re._at(i) != -1:
            if re._at(i) == 92:
                i = _escape(re, i + 1)[1]
            else:
                i += 1
        if re._at(i) != 93:
            raise DecodeError(DecodeError.KIND_CDDL, i)
        return i + 1
    if c == 40:
        var inner = _skip_expr(re, pp + 1)
        if re._at(inner) != 41:
            raise DecodeError(DecodeError.KIND_CDDL, inner)
        return inner + 1
    return pp + 1


def _skip_expr(re: _Re, pp: Int) raises DecodeError -> Int:
    var p = pp
    while True:
        var c = re._at(p)
        if c == -1 or c == 41 or c == 124:
            if c == 124:
                p = _skip_expr(re, p + 1)
                continue
            return p
        if c == 40:
            p = _atom_end(re, p)
            var q = _quant(re, p)
            p = q[2]
            continue
        p = _atom_end(re, p)
        var q2 = _quant(re, p)
        p = q2[2]


def _match_term(mut re: _Re, pp: Int, tp: Int) raises DecodeError -> Tuple[Bool, Int, Int]:
    var c = re._at(pp)
    if c == -1 or c == 41 or c == 124:
        return (True, pp, tp)
    var ends = _factor_ends(re, pp, tp)
    var after = ends[0]
    var i = len(ends[1]) - 1
    while i >= 0:
        var rest = _match_term(re, after, ends[1][i])
        if rest[0]:
            return rest
        i -= 1
    return (False, pp, tp)


def _match_expr(mut re: _Re, pp: Int, tp: Int) raises DecodeError -> Tuple[Bool, Int, Int]:
    var first = _match_term(re, pp, tp)
    if first[0] and (re._at(first[1]) != 124):
        return first
    # try alternatives; find '|' at this expr level
    var p = pp
    var last_fail = first
    while True:
        var term = _match_term(re, p, tp)
        if term[0] and re._at(term[1]) != 124:
            # this alternative consumed and next is end or )
            return term
        if term[0] and re._at(term[1]) == 124:
            # matched a prefix alt that still has | — if term ended at |, this alt succeeded only if we take it
            # _match_term stops before |. If it succeeded, this alt matches.
            return term
        # skip this alt
        var skip = _skip_expr_alt(re, p)
        if re._at(skip) != 124:
            return (False, pp, tp)
        p = skip + 1


def _skip_expr_alt(re: _Re, pp: Int) raises DecodeError -> Int:
    var p = pp
    while True:
        var c = re._at(p)
        if c == -1 or c == 41 or c == 124:
            return p
        p = _atom_end(re, p)
        var q = _quant(re, p)
        p = q[2]


def regexp_fullmatch(pattern: String, text: String) raises DecodeError -> Bool:
    """True when `pattern` matches all of `text`.

    Supports concatenation, `|`, `*+?`, `{n,m}`, `.`, `[]`, capturing `()`,
    `(?:)`, lookahead, lookbehind, backreferences `\\1`–`\\9`, and
    `\\d\\D\\w\\W\\s\\S\\b\\B`.
    """
    var pb = List[Byte]()
    var tb = List[Byte]()
    var ps = pattern.as_bytes()
    var ts = text.as_bytes()
    for i in range(len(ps)):
        pb.append(ps[i])
    for j in range(len(ts)):
        tb.append(ts[j])
    var ntext = len(tb)
    var re = _Re(pb^, tb^)
    var m = _match_expr(re, 0, 0)
    return m[0] and m[2] == ntext and (re._at(m[1]) == -1)
