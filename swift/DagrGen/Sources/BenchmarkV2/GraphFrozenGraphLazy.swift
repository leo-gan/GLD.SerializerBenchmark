import Foundation

extension GraphFrozenGraph {

    public struct VtableOrderArrayAccessor: Sequence {
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
        public subscript(_ idx: Int) -> OrderAccessor {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { throw ArenaRestoreError.outsideOfBuffer }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { throw ArenaRestoreError.outsideOfBuffer }
                return try OrderAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtableOrderArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtableOrderArrayAccessor) { self._acc = acc }
            public mutating func next() -> OrderAccessor? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (OrderAccessor) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (OrderAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> OrderAccessor? {
            guard count > 0 else { return nil }
            return try self[0]
        }
    }

    public struct VtableOrderOptArrayAccessor: Sequence {
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
        public subscript(_ idx: Int) -> OrderAccessor? {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { return nil }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { return nil }
                return try OrderAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtableOrderOptArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtableOrderOptArrayAccessor) { self._acc = acc }
            public mutating func next() -> OrderAccessor?? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (OrderAccessor?) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (OrderAccessor?) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> OrderAccessor?? {
            guard count > 0 else { return .some(nil) }
            return try self[0]
        }
    }

    public struct VtablePersonArrayAccessor: Sequence {
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
        public subscript(_ idx: Int) -> PersonAccessor {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { throw ArenaRestoreError.outsideOfBuffer }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { throw ArenaRestoreError.outsideOfBuffer }
                return try PersonAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtablePersonArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtablePersonArrayAccessor) { self._acc = acc }
            public mutating func next() -> PersonAccessor? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (PersonAccessor) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (PersonAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> PersonAccessor? {
            guard count > 0 else { return nil }
            return try self[0]
        }
    }

    public struct VtablePersonOptArrayAccessor: Sequence {
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
        public subscript(_ idx: Int) -> PersonAccessor? {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { return nil }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { return nil }
                return try PersonAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtablePersonOptArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtablePersonOptArrayAccessor) { self._acc = acc }
            public mutating func next() -> PersonAccessor?? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (PersonAccessor?) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (PersonAccessor?) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> PersonAccessor?? {
            guard count > 0 else { return .some(nil) }
            return try self[0]
        }
    }

    public struct PackedOrderNodeArrayAccessor: Sequence {
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
            private let _acc: PackedOrderNodeArrayAccessor
            private var _i: Int = 0
            private var _p: Int
            init(_ acc: PackedOrderNodeArrayAccessor) { self._acc = acc; self._p = acc._start }
            public mutating func next() -> OrderPackedAccessor? {
                guard _i < _acc.count, _p >= 0 else { return nil }
                guard let (nb, nbB) = try? restoreLEB(from: _acc._data, at: _p) else { return nil }
                let elem = try? OrderPackedAccessor(data: _acc._data, at: _p)
                _i += 1; _p += nbB + Int(nb)
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (OrderPackedAccessor) throws -> Void) throws {
            guard _start >= 0 else { return }
            var p = _start
            for _ in 0..<count {
                let (nb, nbB) = try restoreLEB(from: _data, at: p)
                try body(try OrderPackedAccessor(data: _data, at: p))
                p += nbB + Int(nb)
            }
        }
        public func throwingMap<T>(_ transform: (OrderPackedAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            try throwingForEach { try result.append(transform($0)) }
            return result
        }
        public func throwingFirst() throws -> OrderPackedAccessor? {
            guard _start >= 0, count > 0 else { return nil }
            let (_, _) = try restoreLEB(from: _data, at: _start)
            return try OrderPackedAccessor(data: _data, at: _start)
        }
    }

    public struct PackedPersonNodeArrayAccessor: Sequence {
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
            private let _acc: PackedPersonNodeArrayAccessor
            private var _i: Int = 0
            private var _p: Int
            init(_ acc: PackedPersonNodeArrayAccessor) { self._acc = acc; self._p = acc._start }
            public mutating func next() -> PersonPackedAccessor? {
                guard _i < _acc.count, _p >= 0 else { return nil }
                guard let (nb, nbB) = try? restoreLEB(from: _acc._data, at: _p) else { return nil }
                let elem = try? PersonPackedAccessor(data: _acc._data, at: _p)
                _i += 1; _p += nbB + Int(nb)
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (PersonPackedAccessor) throws -> Void) throws {
            guard _start >= 0 else { return }
            var p = _start
            for _ in 0..<count {
                let (nb, nbB) = try restoreLEB(from: _data, at: p)
                try body(try PersonPackedAccessor(data: _data, at: p))
                p += nbB + Int(nb)
            }
        }
        public func throwingMap<T>(_ transform: (PersonPackedAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            try throwingForEach { try result.append(transform($0)) }
            return result
        }
        public func throwingFirst() throws -> PersonPackedAccessor? {
            guard _start >= 0, count > 0 else { return nil }
            let (_, _) = try restoreLEB(from: _data, at: _start)
            return try PersonPackedAccessor(data: _data, at: _start)
        }
    }

    public struct RegionAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // code
        private var _p1: Int?  // note
        private var _p2: Int?  // version

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
                _cur += 4
            }
        }

        public var code: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var note: String? {
            get throws {
                guard let pos = _p1 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var version: Int32? {
            get throws {
                guard let pos = _p2 else { return nil }
                return try Int32.restore(from: _data, at: pos)
            }
        }

    }

    public struct RegionPackedAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // code
        private var _r1: Range<Int>? = nil  // note
        private var _v2: Int32? = nil  // version

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
                    _v2 = try Int32.restore(from: data, at: _cur); _cur += 4
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v2 = Int32(_v.fromZigZag); _cur += _vB
                }
            }
        }

        public var code: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var note: String? {
            guard let r = _r1 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var version: Int32? { return _v2 }

    }

    public struct OrderAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // sku
        private var _p1: Int?  // qty
        private var _p2: Int?  // region

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
                _cur += 4
            }
            if _obs0 & 4 != 0 {
                _p2 = _cur
                let (_, _bdB2) = try readZigZagV62(from: data, at: _cur)
                _cur += _bdB2
            }
        }

        public var sku: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var qty: Int32? {
            get throws {
                guard let pos = _p1 else { return nil }
                return try Int32.restore(from: _data, at: pos)
            }
        }

        public var region: RegionAccessor? {
            get throws {
                guard let pos = _p2 else { return nil }
                let (bd, bdB) = try readZigZagV62(from: _data, at: pos)
                return try RegionAccessor(data: _data, at: pos + bdB + bd)
            }
        }

    }

    public struct OrderPackedAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // sku
        private var _v1: Int32? = nil  // qty
        private var _n2: Int? = nil  // region

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
                if _ebs0 & 1 != 0 {
                    _v1 = try Int32.restore(from: data, at: _cur); _cur += 4
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v1 = Int32(_v.fromZigZag); _cur += _vB
                }
            }
            if _obs0 & 4 != 0 {
                let (_bbl2, _bblB2) = try restoreLEB(from: data, at: _cur)
                _n2 = _cur
                _cur += _bblB2 + Int(_bbl2)
            }
        }

        public var sku: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var qty: Int32? { return _v1 }

        public var region: RegionPackedAccessor? {
            get throws {
                guard let pos = _n2 else { return nil }
                return try RegionPackedAccessor(data: _data, at: pos)
            }
        }

    }

    public struct PersonAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // name
        private var _p1: Int?  // next

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
                let (_, _bdB1) = try readZigZagV62(from: data, at: _cur)
                _cur += _bdB1
            }
        }

        public var name: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var next: PersonAccessor? {
            get throws {
                guard let pos = _p1 else { return nil }
                let (bd, bdB) = try readZigZagV62(from: _data, at: pos)
                return try PersonAccessor(data: _data, at: pos + bdB + bd)
            }
        }

    }

    public struct PersonPackedAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // name
        private var _n1: Int? = nil  // next

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
                let (_bbl1, _bblB1) = try restoreLEB(from: data, at: _cur)
                _n1 = _cur
                _cur += _bblB1 + Int(_bbl1)
            }
        }

        public var name: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var next: PersonPackedAccessor? {
            get throws {
                guard let pos = _n1 else { return nil }
                return try PersonPackedAccessor(data: _data, at: pos)
            }
        }

    }

    public struct BookAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // orders
        private var _p1: Int?  // people

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            var _cur = start + 1
            _p0 = _cur
            let (_, _fwdB0) = try readV62(from: data, at: _cur)
            _cur += _fwdB0
            _p1 = _cur
            let (_, _fwdB1) = try readV62(from: data, at: _cur)
            _cur += _fwdB1
        }

        public var orders: VtableOrderArrayAccessor {
            get throws {
                guard let pos = _p0 else { return VtableOrderArrayAccessor(_data, at: -1) }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return VtableOrderArrayAccessor(_data, at: pos + fwdB + Int(fwd))
            }
        }

        public var people: VtablePersonArrayAccessor {
            get throws {
                guard let pos = _p1 else { return VtablePersonArrayAccessor(_data, at: -1) }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return VtablePersonArrayAccessor(_data, at: pos + fwdB + Int(fwd))
            }
        }

    }

    public static func lazyRoot(from data: Foundation.Data) throws -> BookAccessor {
        try lazyRoot(from: data, at: 0)
    }
    public static func lazyRoot(from data: Foundation.Data, at start: Int) throws -> BookAccessor {
        let (framing, hdrBytes) = try restoreLEB(from: data, at: start)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        return try BookAccessor(data: data, at: start + hdrBytes + Int(framing >> 2))
    }


}
