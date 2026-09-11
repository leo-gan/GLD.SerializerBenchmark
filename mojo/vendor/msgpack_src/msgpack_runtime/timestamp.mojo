from msgpack_wire.writer import WireWriter


struct MsgpackTimestamp(Copyable, ImplicitlyCopyable, Movable):
    var sec: Int64
    var nsec: Int

    def __init__(out self, sec: Int64 = Int64(0), nsec: Int = 0):
        self.sec = sec
        self.nsec = nsec

    def encoded_len(self) -> Int:
        if self.nsec < 0 or self.nsec >= 1_000_000_000:
            return 15
        if self.nsec == 0 and self.sec >= Int64(0) and self.sec <= Int64(4294967295):
            return 6
        if self.sec >= Int64(0) and self.sec < (Int64(1) << Int64(34)):
            return 10
        return 15

    def encode_to(self, mut w: WireWriter):
        var nsec = self.nsec
        if nsec < 0:
            nsec = 0
        if nsec >= 1_000_000_000:
            nsec = 999_999_999
        if nsec == 0 and self.sec >= Int64(0) and self.sec <= Int64(4294967295):
            w.write_ext_header(Int8(-1), 4)
            w.write_be(UInt64(self.sec), 4)
            return
        if self.sec >= Int64(0) and self.sec < (Int64(1) << Int64(34)):
            var packed = (UInt64(nsec) << UInt64(34)) | UInt64(self.sec)
            w.write_ext_header(Int8(-1), 8)
            w.write_be(packed, 8)
            return
        w.write_ext_header(Int8(-1), 12)
        w.write_be(UInt64(nsec), 4)
        w.write_be(UInt64(self.sec), 8)
