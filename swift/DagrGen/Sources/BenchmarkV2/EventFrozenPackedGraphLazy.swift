import Foundation

extension EventFrozenPackedGraph {

    public struct PackedEventAttrNodeArrayAccessor: Sequence {
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
            private let _acc: PackedEventAttrNodeArrayAccessor
            private var _i: Int = 0
            private var _p: Int
            init(_ acc: PackedEventAttrNodeArrayAccessor) { self._acc = acc; self._p = acc._start }
            public mutating func next() -> EventAttrAccessor? {
                guard _i < _acc.count, _p >= 0 else { return nil }
                guard let (nb, nbB) = try? restoreLEB(from: _acc._data, at: _p) else { return nil }
                let elem = try? EventAttrAccessor(data: _acc._data, at: _p)
                _i += 1; _p += nbB + Int(nb)
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (EventAttrAccessor) throws -> Void) throws {
            guard _start >= 0 else { return }
            var p = _start
            for _ in 0..<count {
                let (nb, nbB) = try restoreLEB(from: _data, at: p)
                try body(try EventAttrAccessor(data: _data, at: p))
                p += nbB + Int(nb)
            }
        }
        public func throwingMap<T>(_ transform: (EventAttrAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            try throwingForEach { try result.append(transform($0)) }
            return result
        }
        public func throwingFirst() throws -> EventAttrAccessor? {
            guard _start >= 0, count > 0 else { return nil }
            let (_, _) = try restoreLEB(from: _data, at: _start)
            return try EventAttrAccessor(data: _data, at: _start)
        }
    }

    public struct EventAttrAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // key
        private var _r1: Range<Int>? = nil  // value

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let (_, _blB) = try restoreLEB(from: data, at: start)
            var _cur = start + _blB
            let _obs0: UInt8 = _cur + 0 < data.count ? data[_cur + 0] : 0
            _cur += 1
            if _obs0 & 1 != 0 {
                let (_sv0, _svB0) = try restoreLEB(from: data, at: _cur)
                _cur += _svB0
                _r0 = _cur ..< (_cur + Int(_sv0))
                _cur += Int(_sv0)
            }
            if _obs0 & 2 != 0 {
                let (_sv1, _svB1) = try restoreLEB(from: data, at: _cur)
                _cur += _svB1
                _r1 = _cur ..< (_cur + Int(_sv1))
                _cur += Int(_sv1)
            }
        }

        public var key: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var value: String? {
            guard let r = _r1 else { return nil }
            return _dagrUTF8(_data[r])
        }

    }

    public struct EventAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // event_id
        private var _r1: Range<Int>? = nil  // event_type
        private var _v2: Int64? = nil  // occurred_at
        private var _r3: Range<Int>? = nil  // producer
        private var _r4: Range<Int>? = nil  // attrs

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
                let (_sv0, _svB0) = try restoreLEB(from: data, at: _cur)
                _cur += _svB0
                _r0 = _cur ..< (_cur + Int(_sv0))
                _cur += Int(_sv0)
            }
            if _obs0 & 2 != 0 {
                let (_sv1, _svB1) = try restoreLEB(from: data, at: _cur)
                _cur += _svB1
                _r1 = _cur ..< (_cur + Int(_sv1))
                _cur += Int(_sv1)
            }
            if _obs0 & 4 != 0 {
                if _ebs0 & 1 != 0 {
                    _v2 = try Int64.restore(from: data, at: _cur); _cur += 8
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v2 = Int64(_v.fromZigZag); _cur += _vB
                }
            }
            if _obs0 & 8 != 0 {
                let (_sv3, _svB3) = try restoreLEB(from: data, at: _cur)
                _cur += _svB3
                _r3 = _cur ..< (_cur + Int(_sv3))
                _cur += Int(_sv3)
            }
            let (_abl4, _ablB4) = try restoreLEB(from: data, at: _cur)
            _r4 = (_cur + _ablB4) ..< (_cur + _ablB4 + Int(_abl4))
            _cur += _ablB4 + Int(_abl4)
        }

        public var event_id: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var event_type: String? {
            guard let r = _r1 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var occurred_at: Int64? { return _v2 }

        public var producer: String? {
            guard let r = _r3 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var attrs: PackedEventAttrNodeArrayAccessor {
            if let __r = _r4 { return PackedEventAttrNodeArrayAccessor(_data, at: __r.lowerBound) }
            return PackedEventAttrNodeArrayAccessor(_data, at: -1)
        }

    }

    public static func lazyRoot(from data: Foundation.Data) throws -> EventAccessor {
        try lazyRoot(from: data, at: 0)
    }
    public static func lazyRoot(from data: Foundation.Data, at start: Int) throws -> EventAccessor {
        let (framing, hdrBytes) = try restoreLEB(from: data, at: start)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        return try EventAccessor(data: data, at: start + hdrBytes + Int(framing >> 2))
    }


}
