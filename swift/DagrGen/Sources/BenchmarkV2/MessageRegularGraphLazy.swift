import Foundation

extension MessageRegularGraph {

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
            let vtable = try restoreRTypeVTable(from: data, start: start)
            _p0 = 0 < vtable.count ? vtable[0].map { start + Int($0) } : nil
            _p1 = 1 < vtable.count ? vtable[1].map { start + Int($0) } : nil
            _p2 = 2 < vtable.count ? vtable[2].map { start + Int($0) } : nil
            _p3 = 3 < vtable.count ? vtable[3].map { start + Int($0) } : nil
            _p4 = 4 < vtable.count ? vtable[4].map { start + Int($0) } : nil
            _p5 = 5 < vtable.count ? vtable[5].map { start + Int($0) } : nil
            _p6 = 6 < vtable.count ? vtable[6].map { start + Int($0) } : nil
            _p7 = 7 < vtable.count ? vtable[7].map { start + Int($0) } : nil
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
