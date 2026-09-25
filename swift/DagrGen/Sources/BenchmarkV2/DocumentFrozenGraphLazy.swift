import Foundation

extension DocumentFrozenGraph {

    public struct VtableDocumentItemArrayAccessor: Sequence {
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
        public subscript(_ idx: Int) -> DocumentItemAccessor {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { throw ArenaRestoreError.outsideOfBuffer }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { throw ArenaRestoreError.outsideOfBuffer }
                return try DocumentItemAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtableDocumentItemArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtableDocumentItemArrayAccessor) { self._acc = acc }
            public mutating func next() -> DocumentItemAccessor? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (DocumentItemAccessor) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (DocumentItemAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> DocumentItemAccessor? {
            guard count > 0 else { return nil }
            return try self[0]
        }
    }

    public struct VtableDocumentItemOptArrayAccessor: Sequence {
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
        public subscript(_ idx: Int) -> DocumentItemAccessor? {
            get throws {
                guard _slotStart >= 0, idx >= 0, idx < count else { return nil }
                let ro = try readSignedRelOffset(from: _data, at: _slotStart + idx * _es, size: _es)
                guard ro != 0 else { return nil }
                return try DocumentItemAccessor(data: _data, at: _base + Int(ro) - 1)
            }
        }
        public struct Iterator: IteratorProtocol {
            private let _acc: VtableDocumentItemOptArrayAccessor
            private var _i: Int = 0
            init(_ acc: VtableDocumentItemOptArrayAccessor) { self._acc = acc }
            public mutating func next() -> DocumentItemAccessor?? {
                guard _i < _acc.count else { return nil }
                let elem = try? _acc[_i]
                _i += 1
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (DocumentItemAccessor?) throws -> Void) throws {
            for i in 0..<count { try body(try self[i]) }
        }
        public func throwingMap<T>(_ transform: (DocumentItemAccessor?) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            for i in 0..<count { try result.append(transform(try self[i])) }
            return result
        }
        public func throwingFirst() throws -> DocumentItemAccessor?? {
            guard count > 0 else { return .some(nil) }
            return try self[0]
        }
    }

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
            public mutating func next() -> DocumentItemPackedAccessor? {
                guard _i < _acc.count, _p >= 0 else { return nil }
                guard let (nb, nbB) = try? restoreLEB(from: _acc._data, at: _p) else { return nil }
                let elem = try? DocumentItemPackedAccessor(data: _acc._data, at: _p)
                _i += 1; _p += nbB + Int(nb)
                return elem
            }
        }
        public func makeIterator() -> Iterator { Iterator(self) }
        public func throwingForEach(_ body: (DocumentItemPackedAccessor) throws -> Void) throws {
            guard _start >= 0 else { return }
            var p = _start
            for _ in 0..<count {
                let (nb, nbB) = try restoreLEB(from: _data, at: p)
                try body(try DocumentItemPackedAccessor(data: _data, at: p))
                p += nbB + Int(nb)
            }
        }
        public func throwingMap<T>(_ transform: (DocumentItemPackedAccessor) throws -> T) throws -> [T] {
            var result = [T](); result.reserveCapacity(count)
            try throwingForEach { try result.append(transform($0)) }
            return result
        }
        public func throwingFirst() throws -> DocumentItemPackedAccessor? {
            guard _start >= 0, count > 0 else { return nil }
            let (_, _) = try restoreLEB(from: _data, at: _start)
            return try DocumentItemPackedAccessor(data: _data, at: _start)
        }
    }

    public struct DocumentMetaAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // region
        private var _p1: Int?  // version

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
        }

        public var region: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var version: Int32? {
            get throws {
                guard let pos = _p1 else { return nil }
                return try Int32.restore(from: _data, at: pos)
            }
        }

    }

    public struct DocumentMetaPackedAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // region
        private var _v1: Int32? = nil  // version

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
        private var _p0: Int?  // sku
        private var _p1: Int?  // qty
        private var _p2: Int?  // price_minor

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
                _cur += 8
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

        public var price_minor: Int64? {
            get throws {
                guard let pos = _p2 else { return nil }
                return try Int64.restore(from: _data, at: pos)
            }
        }

    }

    public struct DocumentItemPackedAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // sku
        private var _v1: Int32? = nil  // qty
        private var _v2: Int64? = nil  // price_minor

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
                if _ebs0 & 2 != 0 {
                    _v2 = try Int64.restore(from: data, at: _cur); _cur += 8
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v2 = Int64(_v.fromZigZag); _cur += _vB
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
        private var _p0: Int?  // id
        private var _p1: Int?  // status
        private var _p2: Int?  // meta
        private var _p3: Int?  // items

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
            _p3 = _cur
            let (_, _fwdB3) = try readV62(from: data, at: _cur)
            _cur += _fwdB3
        }

        public var id: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var status: Int32? {
            get throws {
                guard let pos = _p1 else { return nil }
                return try Int32.restore(from: _data, at: pos)
            }
        }

        public var meta: DocumentMetaAccessor? {
            get throws {
                guard let pos = _p2 else { return nil }
                let (bd, bdB) = try readZigZagV62(from: _data, at: pos)
                return try DocumentMetaAccessor(data: _data, at: pos + bdB + bd)
            }
        }

        public var items: VtableDocumentItemArrayAccessor {
            get throws {
                guard let pos = _p3 else { return VtableDocumentItemArrayAccessor(_data, at: -1) }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return VtableDocumentItemArrayAccessor(_data, at: pos + fwdB + Int(fwd))
            }
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
