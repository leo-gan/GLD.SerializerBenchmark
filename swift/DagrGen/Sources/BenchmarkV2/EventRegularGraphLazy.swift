import Foundation

extension EventRegularGraph {

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

    public struct EventAttrAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // key
        private var _p1: Int?  // value

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let vtable = try restoreRTypeVTable(from: data, start: start)
            _p0 = 0 < vtable.count ? vtable[0].map { start + Int($0) } : nil
            _p1 = 1 < vtable.count ? vtable[1].map { start + Int($0) } : nil
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
            let vtable = try restoreRTypeVTable(from: data, start: start)
            _p0 = 0 < vtable.count ? vtable[0].map { start + Int($0) } : nil
            _p1 = 1 < vtable.count ? vtable[1].map { start + Int($0) } : nil
            _p2 = 2 < vtable.count ? vtable[2].map { start + Int($0) } : nil
            _p3 = 3 < vtable.count ? vtable[3].map { start + Int($0) } : nil
            _p4 = 4 < vtable.count ? vtable[4].map { start + Int($0) } : nil
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
