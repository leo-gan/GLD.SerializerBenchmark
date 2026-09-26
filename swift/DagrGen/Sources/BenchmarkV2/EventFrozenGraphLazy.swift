import Foundation

extension EventFrozenGraph {

    public struct VtableEventAttrArrayAccessor: Sequence {
        internal let _data: Foundation.Data
        private let _slotStart: Int
        private let _es: Int
        private let _base: Int
        public let count: Int
        public init(_ data: Foundation.Data, at pos: Int) {
            _data = data
            if pos >= 0, let (hdr, hLen) = try? restoreLEB(from: data, at: pos) {
                count = Int(hdr >> 2); let es = [1,2,4,8][Int(hdr&3)]
                _slotStart = pos + hLen; _es = es; _base = pos + hLen + count * es
            } else { count = 0; _slotStart = -1; _es = 1; _base = 0 }
        }
        public subscript(_ idx: Int) -> EventAttrAccessor {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { throw ArenaRestoreError.outsideOfBuffer }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { throw ArenaRestoreError.outsideOfBuffer }
                return try EventAttrAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtableEventAttrArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtableEventAttrArrayAccessor) { self._acc = acc }
            public mutating func next() -> EventAttrAccessor? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (EventAttrAccessor) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (EventAttrAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> EventAttrAccessor? {
            guard count > 0 else { return nil }
            return try self[0]
        }
    }

    public struct VtableEventAttrOptArrayAccessor: Sequence {
        internal let _data: Foundation.Data
        private let _slotStart: Int
        private let _es: Int
        private let _base: Int
        public let count: Int
        public init(_ data: Foundation.Data, at pos: Int) {
            _data = data
            if pos >= 0, let (hdr, hLen) = try? restoreLEB(from: data, at: pos) {
                count = Int(hdr >> 2); let es = [1,2,4,8][Int(hdr&3)]
                _slotStart = pos + hLen; _es = es; _base = pos + hLen + count * es
            } else { count = 0; _slotStart = -1; _es = 1; _base = 0 }
        }
        public subscript(_ idx: Int) -> EventAttrAccessor? {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { return nil }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { return nil }
                return try EventAttrAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtableEventAttrOptArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtableEventAttrOptArrayAccessor) { self._acc = acc }
            public mutating func next() -> EventAttrAccessor?? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (EventAttrAccessor?) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (EventAttrAccessor?) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> EventAttrAccessor?? {
            guard count > 0 else { return .some(nil) }
            return try self[0]
        }
    }

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
            public mutating func next() -> EventAttrPackedAccessor? {
                guard _i < _acc.count, _p >= 0 else { return nil }
                guard let (nb, nbB) = try? restoreLEB(from: _acc._data, at: _p) else { return nil }
                let elem = try? EventAttrPackedAccessor(data: _acc._data, at: _p)
                _i += 1; _p += nbB + Int(nb)
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (EventAttrPackedAccessor) throws -> Void) throws {
            guard _start >= 0 else { return }
            var p = _start
            for _ in 0..<count {
                let (nb, nbB) = try restoreLEB(from: _data, at: p)
                try body(try EventAttrPackedAccessor(data: _data, at: p))
                p += nbB + Int(nb)
            }
        }
        public func throwingMap<T>(_ transform: (EventAttrPackedAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            try throwingForEach { try result.append(transform($0)) }
            return result
        }
        public func throwingFirst() throws -> EventAttrPackedAccessor? {
            guard _start >= 0, count > 0 else { return nil }
            let (_, _) = try restoreLEB(from: _data, at: _start)
            return try EventAttrPackedAccessor(data: _data, at: _start)
        }
    }

    public struct EventAttrAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // key
        private var _p1: Int?  // value

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let _obs0: UInt8 = start + 0 < data.count ? data[start + 0] : 0
            var _cur = start + 1
            if _obs0 & 1 != 0 {
                _p0 = _cur
                let (_, _fwdB0) = try readV62(from: data, at: _cur)
                _cur += _fwdB0
            }
            if _obs0 & 2 != 0 {
                _p1 = _cur
                let (_, _fwdB1) = try readV62(from: data, at: _cur)
                _cur += _fwdB1
            }
        }

        public var key: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var value: String? {
            get throws {
                guard let pos = _p1 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

    }

    public struct EventAttrPackedAccessor {
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
        private var _p0: Int?  // event_id
        private var _p1: Int?  // event_type
        private var _p2: Int?  // occurred_at
        private var _p3: Int?  // producer
        private var _p4: Int?  // attrs

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let _obs0: UInt8 = start + 0 < data.count ? data[start + 0] : 0
            var _cur = start + 1
            if _obs0 & 1 != 0 {
                _p0 = _cur
                let (_, _fwdB0) = try readV62(from: data, at: _cur)
                _cur += _fwdB0
            }
            if _obs0 & 2 != 0 {
                _p1 = _cur
                let (_, _fwdB1) = try readV62(from: data, at: _cur)
                _cur += _fwdB1
            }
            if _obs0 & 4 != 0 {
                _p2 = _cur
                _cur += 8
            }
            if _obs0 & 8 != 0 {
                _p3 = _cur
                let (_, _fwdB3) = try readV62(from: data, at: _cur)
                _cur += _fwdB3
            }
            _p4 = _cur
            let (_, _fwdB4) = try readV62(from: data, at: _cur)
            _cur += _fwdB4
        }

        public var event_id: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var event_type: String? {
            get throws {
                guard let pos = _p1 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var occurred_at: Int64? {
            get throws {
                guard let pos = _p2 else { return nil }
                return try Int64.restore(from: _data, at: pos)
            }
        }

        public var producer: String? {
            get throws {
                guard let pos = _p3 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var attrs: VtableEventAttrArrayAccessor {
            get throws {
                guard let pos = _p4 else { return VtableEventAttrArrayAccessor(_data, at: -1) }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return VtableEventAttrArrayAccessor(_data, at: pos + fwdB + Int(fwd))
            }
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
