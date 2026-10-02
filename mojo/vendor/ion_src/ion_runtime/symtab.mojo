from std.collections import List

from ion_runtime.error import DecodeError


comptime SYS_MAX = 9


def sys_name(sid: Int) -> String:
    if sid == 1:
        return "$ion"
    if sid == 2:
        return "$ion_1_0"
    if sid == 3:
        return "$ion_symbol_table"
    if sid == 4:
        return "name"
    if sid == 5:
        return "version"
    if sid == 6:
        return "imports"
    if sid == 7:
        return "symbols"
    if sid == 8:
        return "max_id"
    if sid == 9:
        return "$ion_shared_symbol_table"
    return String()


def sys_sid(text: String) -> Int:
    var raw = text.as_bytes()
    var n = len(raw)
    if n == 0:
        return 0
    if n == 4 and Int(raw[0]) == 110 and Int(raw[1]) == 97 and Int(raw[2]) == 109 and Int(raw[3]) == 101:
        return 4
    if Int(raw[0]) != 36 and n != 7 and n != 6 and n != 8 and n != 25:
        return 0
    if text == "$ion":
        return 1
    if text == "$ion_1_0":
        return 2
    if text == "$ion_symbol_table":
        return 3
    if text == "version":
        return 5
    if text == "imports":
        return 6
    if text == "symbols":
        return 7
    if text == "max_id":
        return 8
    if text == "$ion_shared_symbol_table":
        return 9
    return 0


struct SharedTable(Movable):
    """One version of a shared symbol table. `texts[0]` is symbol id 1. `gap[i]` is true when that id has no text."""

    var name: String
    var version: Int
    var texts: List[String]
    var gap: List[Bool]

    def __init__(out self, name: String, version: Int):
        self.name = name
        self.version = version
        self.texts = List[String]()
        self.gap = List[Bool]()

    def add(mut self, text: String, is_gap: Bool):
        self.texts.append(text)
        self.gap.append(is_gap)


struct Catalog(Movable):
    var tables: List[SharedTable]

    def __init__(out self):
        self.tables = List[SharedTable]()

    def add(mut self, var table: SharedTable):
        self.tables.append(table^)

    def exact(self, name: String, version: Int) -> Int:
        var i = 0
        while i < len(self.tables):
            if self.tables[i].name == name and self.tables[i].version == version:
                return i
            i += 1
        return -1

    def greatest(self, name: String) -> Int:
        var best = -1
        var best_ver = -1
        var i = 0
        while i < len(self.tables):
            if self.tables[i].name == name and self.tables[i].version > best_ver:
                best = i
                best_ver = self.tables[i].version
            i += 1
        return best


struct TabSeg(Copyable, ImplicitlyCopyable):
    """A contiguous run of symbol ids. `name_at` -1 means a local run stored in `LocalTab.text`."""

    var start: Int
    var count: Int
    var flat_at: Int
    var flat_n: Int
    var name_at: Int

    def __init__(out self):
        self.start = 0
        self.count = 0
        self.flat_at = -1
        self.flat_n = 0
        self.name_at = -1


struct Resolved:
    var known: Bool
    var text: String
    var imp: String
    var imp_sid: Int

    def __init__(out self):
        self.known = False
        self.text = String()
        self.imp = String()
        self.imp_sid = 0


struct LocalTab(Movable):
    """The current symbol address space. System symbols occupy ids 1 through 9."""

    var text: List[String]
    var known: List[Bool]
    var names: List[String]
    var segs: List[TabSeg]
    var max_id: Int

    def __init__(out self):
        self.text = List[String]()
        self.known = List[Bool]()
        self.names = List[String]()
        self.segs = List[TabSeg]()
        self.max_id = SYS_MAX
        self.text.append(String())
        self.known.append(False)
        var seg = TabSeg()
        seg.start = 1
        seg.count = SYS_MAX
        seg.flat_at = 1
        seg.flat_n = 0
        self.segs.append(seg)

    def reset_system(mut self):
        while len(self.segs) > 1:
            _ = self.segs.pop()
        while len(self.text) > 1:
            _ = self.text.pop()
            _ = self.known.pop()
        self.max_id = SYS_MAX
        var seg = self.segs[0]
        seg.count = SYS_MAX
        seg.flat_n = 0
        self.segs[0] = seg

    def _add_flat(mut self, var text: String, is_known: Bool) -> Int:
        var last_i = len(self.segs) - 1
        var last = self.segs[last_i]
        if last.name_at < 0 and last.start + last.count == self.max_id + 1 and last_i > 0:
            self.text.append(text^)
            self.known.append(is_known)
            last.count += 1
            last.flat_n += 1
            self.segs[last_i] = last
            self.max_id += 1
            return self.max_id
        var seg = TabSeg()
        seg.start = self.max_id + 1
        seg.count = 1
        seg.flat_at = len(self.text)
        seg.flat_n = 1
        self.text.append(text^)
        self.known.append(is_known)
        self.segs.append(seg)
        self.max_id += 1
        return self.max_id

    def add_text(mut self, var text: String) -> Int:
        return self._add_flat(text^, True)

    def add_gap(mut self) -> Int:
        return self._add_flat(String(), False)

    def sid_of(self, text: String) -> Int:
        var sys = sys_sid(text)
        if sys != 0:
            return sys
        var s = 0
        while s < len(self.segs):
            var seg = self.segs[s]
            if seg.flat_n > 0:
                var i = 0
                while i < seg.flat_n:
                    var at = seg.flat_at + i
                    if self.known[at] and self.text[at] == text:
                        return seg.start + i
                    i += 1
            s += 1
        return 0

    def lookup(self, sid: Int, offset: Int) raises DecodeError -> Resolved:
        var out = Resolved()
        if sid < 0 or sid > self.max_id:
            raise DecodeError(DecodeError.KIND_SYMBOL, offset)
        if sid == 0:
            return out^
        if sid <= SYS_MAX:
            out.known = True
            out.text = sys_name(sid)
            return out^
        var s = 0
        while s < len(self.segs):
            var seg = self.segs[s]
            if sid >= seg.start and sid < seg.start + seg.count:
                var off = sid - seg.start
                if seg.name_at < 0:
                    var at = seg.flat_at + off
                    if self.known[at]:
                        out.known = True
                        out.text = self.text[at]
                    return out^
                if off < seg.flat_n and self.known[seg.flat_at + off]:
                    out.known = True
                    out.text = self.text[seg.flat_at + off]
                    return out^
                out.imp = self.names[seg.name_at]
                out.imp_sid = off + 1
                return out^
            s += 1
        raise DecodeError(DecodeError.KIND_SYMBOL, offset)

    def import_table(mut self, table: SharedTable, max_id: Int, offset: Int) raises DecodeError:
        """Allocate `max_id` ids. Only the shared table's real symbols are stored; the tail stays unknown."""
        if max_id < 0:
            raise DecodeError(DecodeError.KIND_SYMBOL, offset)
        var prefix = len(table.texts)
        if prefix > max_id:
            prefix = max_id
        var seg = TabSeg()
        seg.start = self.max_id + 1
        seg.count = max_id
        seg.name_at = len(self.names)
        self.names.append(table.name)
        if prefix > 0:
            seg.flat_at = len(self.text)
            seg.flat_n = prefix
            var i = 0
            while i < prefix:
                if table.gap[i]:
                    self.text.append(String())
                    self.known.append(False)
                else:
                    self.text.append(table.texts[i])
                    self.known.append(True)
                i += 1
        self.segs.append(seg)
        self.max_id += max_id
