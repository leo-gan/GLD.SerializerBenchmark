import Foundation

extension TelemetryRegularGraph {

    public struct TelemetryAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // source
        private var _p1: Int?  // ts
        private var _p2: Int?  // tags
        private var _p3: Int?  // values

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let vtable = try restoreRTypeVTable(from: data, start: start)
            _p0 = 0 < vtable.count ? vtable[0].map { start + Int($0) } : nil
            _p1 = 1 < vtable.count ? vtable[1].map { start + Int($0) } : nil
            _p2 = 2 < vtable.count ? vtable[2].map { start + Int($0) } : nil
            _p3 = 3 < vtable.count ? vtable[3].map { start + Int($0) } : nil
        }

        public var source: String? {
            get throws {
                guard let pos = _p0 else { return nil }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return try String.restore(from: _data, at: pos + fwdB + Int(fwd))
            }
        }

        public var ts: Int64? {
            get throws {
                guard let pos = _p1 else { return nil }
                return try Int64.restore(from: _data, at: pos)
            }
        }

        public var tags: VtableUtf8ArrayAccessor {
            get throws {
                guard let pos = _p2 else { return VtableUtf8ArrayAccessor(_data, at: -1) }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return VtableUtf8ArrayAccessor(_data, at: pos + fwdB + Int(fwd))
            }
        }

        public var values: VtableF64ArrayAccessor {
            get throws {
                guard let pos = _p3 else { return VtableF64ArrayAccessor(_data, at: -1) }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return VtableF64ArrayAccessor(_data, at: pos + fwdB + Int(fwd))
            }
        }

    }

    public static func lazyRoot(from data: Foundation.Data) throws -> TelemetryAccessor {
        try lazyRoot(from: data, at: 0)
    }
    public static func lazyRoot(from data: Foundation.Data, at start: Int) throws -> TelemetryAccessor {
        let (framing, hdrBytes) = try restoreLEB(from: data, at: start)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        return try TelemetryAccessor(data: data, at: start + hdrBytes + Int(framing >> 2))
    }


}
