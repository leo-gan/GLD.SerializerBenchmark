import Foundation

extension StringsRegularGraph {

    public struct StringsAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _p0: Int?  // items

        public init(data: Foundation.Data, at start: Int) throws {
            _data = data
            _nodeStart = start
            let vtable = try restoreRTypeVTable(from: data, start: start)
            _p0 = 0 < vtable.count ? vtable[0].map { start + Int($0) } : nil
        }

        public var items: VtableUtf8ArrayAccessor {
            get throws {
                guard let pos = _p0 else { return VtableUtf8ArrayAccessor(_data, at: -1) }
                let (fwd, fwdB) = try readV62(from: _data, at: pos)
                return VtableUtf8ArrayAccessor(_data, at: pos + fwdB + Int(fwd))
            }
        }

    }

    public static func lazyRoot(from data: Foundation.Data) throws -> StringsAccessor {
        try lazyRoot(from: data, at: 0)
    }
    public static func lazyRoot(from data: Foundation.Data, at start: Int) throws -> StringsAccessor {
        let (framing, hdrBytes) = try restoreLEB(from: data, at: start)
        guard (framing & 1) == 0 else { throw ArenaRestoreError.missingHeader }
        return try StringsAccessor(data: data, at: start + hdrBytes + Int(framing >> 2))
    }


}
