import Foundation

extension MessageFrozenGraph {

    public struct MessageAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // f_bool
        private var _p1: Int?  // f_int32
        private var _p2: Int?  // f_int64
        private var _p3: Int?  // f_float64
        private var _p4: Int?  // f_string
        private var _p5: Int?  // f_bool_2
        private var _p6: Int?  // f_int32_2
        private var _p7: Int?  // f_string_2

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let _obs0: UInt8 = start + 0 < data.count ? data[start + 0] : 0
            var _cur = start + 1
            if _obs0 & 1 != 0 {
                _p0 = _cur
                _cur += 1
            }
            if _obs0 & 2 != 0 {
                _p1 = _cur
                _cur += 4
            }
            if _obs0 & 4 != 0 {
                _p2 = _cur
                _cur += 8
            }
            if _obs0 & 8 != 0 {
                _p3 = _cur
                _cur += 8
            }
            if _obs0 & 16 != 0 {
                _p4 = _cur
                let (_, _fwdB4) = try readV62(from: data, at: _cur)
                _cur += _fwdB4
            }
            if _obs0 & 32 != 0 {
                _p5 = _cur
                _cur += 1
            }
            if _obs0 & 64 != 0 {
                _p6 = _cur
                _cur += 4
            }
            if _obs0 & 128 != 0 {
                _p7 = _cur
                let (_, _fwdB7) = try readV62(from: data, at: _cur)
                _cur += _fwdB7
            }
        }

        public var f_bool: Bool? {
            get throws {
                guard let pos = _p0 else { return nil }
                return try Bool.restore(from: _data, at: pos)
            }
        }

        public var f_int32: Int32? {
            get throws {
                guard let pos = _p1 else { return nil }
                return try Int32.restore(from: _data, at: pos)
            }
        }

        public var f_int64: Int64? {
            get throws {
                guard let pos = _p2 else { return nil }
                return try Int64.restore(from: _data, at: pos)
            }
        }

        public var f_float64: Double? {
            get throws {
                guard let pos = _p3 else { return nil }
                return try Double.restore(from: _data, at: pos)
            }
        }

        public var f_string: String? {
            get throws {
                guard let pos = _p4 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var f_bool_2: Bool? {
            get throws {
                guard let pos = _p5 else { return nil }
                return try Bool.restore(from: _data, at: pos)
            }
        }

        public var f_int32_2: Int32? {
            get throws {
                guard let pos = _p6 else { return nil }
                return try Int32.restore(from: _data, at: pos)
            }
        }

        public var f_string_2: String? {
            get throws {
                guard let pos = _p7 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

    }

    public static func lazyRoot(from data: Foundation.Data) throws -> MessageAccessor {
        try lazyRoot(from: data, at: 0)
    }
    public static func lazyRoot(from data: Foundation.Data, at start: Int) throws -> MessageAccessor {
        let (framing, hdrBytes) = try restoreLEB(from: data, at: start)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        return try MessageAccessor(data: data, at: start + hdrBytes + Int(framing >> 2))
    }


}
