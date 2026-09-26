import Foundation

extension MessageFrozenPackedGraph {

    public struct MessageAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _v0: Bool? = nil  // f_bool
        private var _v1: Int32? = nil  // f_int32
        private var _v2: Int64? = nil  // f_int64
        private var _v3: Double? = nil  // f_float64
        private var _r4: Range<Int>? = nil  // f_string
        private var _v5: Bool? = nil  // f_bool_2
        private var _v6: Int32? = nil  // f_int32_2
        private var _r7: Range<Int>? = nil  // f_string_2

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let (_, _blB) = try restoreLEB(from: data, at: start)
            var _cur = start + _blB
            let _obs0: UInt8 = _cur + 0 < data.count ? data[_cur + 0] : 0
            _cur += 1
            let _ebs0: UInt8 = _cur + 0 < data.count ? data[_cur + 0] : 0
            _cur += 1
            if _obs0 & 1 != 0 {
                _v0 = data[_cur] != 0
                _cur += 1
            }
            if _obs0 & 2 != 0 {
                if _ebs0 & 1 != 0 {
                    _v1 = try Int32.restore(from: data, at: _cur); _cur += 4
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v1 = Int32(_v.fromZigZag); _cur += _vB
                }
            }
            if _obs0 & 4 != 0 {
                if _ebs0 & 2 != 0 {
                    _v2 = try Int64.restore(from: data, at: _cur); _cur += 8
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v2 = Int64(_v.fromZigZag); _cur += _vB
                }
            }
            if _obs0 & 8 != 0 {
                if _ebs0 & 4 != 0 {
                    _v3 = try Double.restore(from: data, at: _cur); _cur += 8
                } else {
                    let (_fv, _fvB) = try _decodePackedFloat64(from: data, at: _cur)
                    _v3 = _fv; _cur += _fvB
                }
            }
            if _obs0 & 16 != 0 {
                let (_sv4, _svB4) = try restoreLEB(from: data, at: _cur)
                _cur += _svB4
                _r4 = _cur ..< (_cur + Int(_sv4))
                _cur += Int(_sv4)
            }
            if _obs0 & 32 != 0 {
                _v5 = data[_cur] != 0
                _cur += 1
            }
            if _obs0 & 64 != 0 {
                if _ebs0 & 8 != 0 {
                    _v6 = try Int32.restore(from: data, at: _cur); _cur += 4
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v6 = Int32(_v.fromZigZag); _cur += _vB
                }
            }
            if _obs0 & 128 != 0 {
                let (_sv7, _svB7) = try restoreLEB(from: data, at: _cur)
                _cur += _svB7
                _r7 = _cur ..< (_cur + Int(_sv7))
                _cur += Int(_sv7)
            }
        }

        public var f_bool: Bool? { return _v0 }

        public var f_int32: Int32? { return _v1 }

        public var f_int64: Int64? { return _v2 }

        public var f_float64: Double? { return _v3 }

        public var f_string: String? {
            guard let r = _r4 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var f_bool_2: Bool? { return _v5 }

        public var f_int32_2: Int32? { return _v6 }

        public var f_string_2: String? {
            guard let r = _r7 else { return nil }
            return _dagrUTF8(_data[r])
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
