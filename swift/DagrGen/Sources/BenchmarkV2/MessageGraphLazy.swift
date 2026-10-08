import Foundation

extension MessageGraph {

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
            let (_bl, _blB) = try restoreLEB(from: data, at: start)
            var _cursor = start + _blB
            let _end = _cursor + Int(_bl)

            if _cursor < _end {
                let (_tag0, _tag0B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag0) >> 1 == 0 {
                    _cursor += _tag0B
                    _v0 = data[_cursor] != 0
                    _cursor += 1
                }
            }
            if _cursor < _end {
                let (_tag1, _tag1B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag1) >> 1 == 1 {
                    _cursor += _tag1B
                    if _tag1 & 1 == 0 {
                        let (_v, _vB) = try restoreLEB(from: data, at: _cursor)
                        _v1 = Int32(_v.fromZigZag); _cursor += _vB
                    } else {
                        _v1 = try Int32.restore(from: data, at: _cursor); _cursor += 4
                    }
                }
            }
            if _cursor < _end {
                let (_tag2, _tag2B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag2) >> 1 == 2 {
                    _cursor += _tag2B
                    if _tag2 & 1 == 0 {
                        let (_v, _vB) = try restoreLEB(from: data, at: _cursor)
                        _v2 = Int64(_v.fromZigZag); _cursor += _vB
                    } else {
                        _v2 = try Int64.restore(from: data, at: _cursor); _cursor += 8
                    }
                }
            }
            if _cursor < _end {
                let (_tag3, _tag3B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag3) >> 1 == 3 {
                    _cursor += _tag3B
                    if _tag3 & 1 == 0 {
                        let (_fv, _fvB) = try _decodePackedFloat64(from: data, at: _cursor)
                        _v3 = _fv; _cursor += _fvB
                    } else {
                        _v3 = try Double.restore(from: data, at: _cursor); _cursor += 8
                    }
                }
            }
            if _cursor < _end {
                let (_tag4, _tag4B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag4) >> 1 == 4 {
                    _cursor += _tag4B
                    let (_sv4, _sb4) = try restoreLEB(from: data, at: _cursor)
                    _cursor += _sb4
                    _r4 = _cursor ..< (_cursor + Int(_sv4))
                    _cursor += Int(_sv4)
                }
            }
            if _cursor < _end {
                let (_tag5, _tag5B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag5) >> 1 == 5 {
                    _cursor += _tag5B
                    _v5 = data[_cursor] != 0
                    _cursor += 1
                }
            }
            if _cursor < _end {
                let (_tag6, _tag6B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag6) >> 1 == 6 {
                    _cursor += _tag6B
                    if _tag6 & 1 == 0 {
                        let (_v, _vB) = try restoreLEB(from: data, at: _cursor)
                        _v6 = Int32(_v.fromZigZag); _cursor += _vB
                    } else {
                        _v6 = try Int32.restore(from: data, at: _cursor); _cursor += 4
                    }
                }
            }
            if _cursor < _end {
                let (_tag7, _tag7B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag7) >> 1 == 7 {
                    _cursor += _tag7B
                    let (_sv7, _sb7) = try restoreLEB(from: data, at: _cursor)
                    _cursor += _sb7
                    _r7 = _cursor ..< (_cursor + Int(_sv7))
                    _cursor += Int(_sv7)
                }
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
