import Foundation

extension DocumentGraph {

    public struct PackedDocumentItemNodeArrayAccessor: Sequence {
        fileprivate let _data: Foundation.Data
        fileprivate let _start: Int
        public let count: Int
        public init(_ data: Foundation.Data, at pos: Int) {
            _data = data
            if pos >= 0, let (c, cB) = try? restoreLEB(from: data, at: pos) {
                count = Int(c); _start = pos + cB
            } else { count = 0; _start = -1 }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: PackedDocumentItemNodeArrayAccessor
            private var _i: Int = 0
            private var _p: Int
            init(_ acc: PackedDocumentItemNodeArrayAccessor) { self._acc = acc; self._p = acc._start }
            public mutating func next() -> DocumentItemAccessor? {
                guard _i < _acc.count, _p >= 0 else { return nil }
                guard let (nb, nbB) = try? restoreLEB(from: _acc._data, at: _p) else { return nil }
                let elem = try? DocumentItemAccessor(data: _acc._data, at: _p)
                _i += 1; _p += nbB + Int(nb)
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (DocumentItemAccessor) throws -> Void) throws {
            guard _start >= 0 else { return }
            var p = _start
            for _ in 0..<count {
                let (nb, nbB) = try restoreLEB(from: _data, at: p)
                try body(try DocumentItemAccessor(data: _data, at: p))
                p += nbB + Int(nb)
            }
        }
        public func throwingMap<T>(_ transform: (DocumentItemAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            try throwingForEach { try result.append(transform($0)) }
            return result
        }
        public func throwingFirst() throws -> DocumentItemAccessor? {
            guard _start >= 0, count > 0 else { return nil }
            let (_, _) = try restoreLEB(from: _data, at: _start)
            return try DocumentItemAccessor(data: _data, at: _start)
        }
    }

    public struct DocumentMetaAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // region
        private var _v1: Int32? = nil  // version

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
                    let (_sv0, _sb0) = try restoreLEB(from: data, at: _cursor)
                    _cursor += _sb0
                    _r0 = _cursor ..< (_cursor + Int(_sv0))
                    _cursor += Int(_sv0)
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
        }

        public var region: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var version: Int32? { return _v1 }

    }

    public struct DocumentItemAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // sku
        private var _v1: Int32? = nil  // qty
        private var _v2: Int64? = nil  // price_minor

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
                    let (_sv0, _sb0) = try restoreLEB(from: data, at: _cursor)
                    _cursor += _sb0
                    _r0 = _cursor ..< (_cursor + Int(_sv0))
                    _cursor += Int(_sv0)
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
        }

        public var sku: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var qty: Int32? { return _v1 }

        public var price_minor: Int64? { return _v2 }

    }

    public struct DocumentAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // id
        private var _v1: Int32? = nil  // status
        private var _n2: Int? = nil  // meta
        private var _r3: Range<Int>? = nil  // items

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
                    let (_sv0, _sb0) = try restoreLEB(from: data, at: _cursor)
                    _cursor += _sb0
                    _r0 = _cursor ..< (_cursor + Int(_sv0))
                    _cursor += Int(_sv0)
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
                    let (_bbl2, _bblB2) = try restoreLEB(from: data, at: _cursor)
                    _n2 = _cursor
                    _cursor += _bblB2 + Int(_bbl2)
                }
            }
            if _cursor < _end {
                let (_tag3, _tag3B) = try restoreLEB(from: data, at: _cursor)
                if Int(_tag3) >> 1 == 3 {
                    _cursor += _tag3B
                    let (_abl3, _ablB3) = try restoreLEB(from: data, at: _cursor)
                    _r3 = (_cursor + _ablB3) ..< (_cursor + _ablB3 + Int(_abl3))
                    _cursor += _ablB3 + Int(_abl3)
                }
            }
        }

        public var id: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var status: Int32? { return _v1 }

        public var meta: DocumentMetaAccessor? {
            get throws {
                guard let pos = _n2 else { return nil }
                return try DocumentMetaAccessor(data: _data, at: pos)
            }
        }

        public var items: PackedDocumentItemNodeArrayAccessor {
            if let __r = _r3 { return PackedDocumentItemNodeArrayAccessor(_data, at: __r.lowerBound) }
            return PackedDocumentItemNodeArrayAccessor(_data, at: -1)
        }

    }

    public static func lazyRoot(from data: Foundation.Data) throws -> DocumentAccessor {
        try lazyRoot(from: data, at: 0)
    }
    public static func lazyRoot(from data: Foundation.Data, at start: Int) throws -> DocumentAccessor {
        let (framing, hdrBytes) = try restoreLEB(from: data, at: start)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        return try DocumentAccessor(data: data, at: start + hdrBytes + Int(framing >> 2))
    }


}
