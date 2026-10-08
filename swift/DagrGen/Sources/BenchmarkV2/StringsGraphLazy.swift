import Foundation

extension StringsGraph {

    public struct StringsAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // items

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
                    let (_abl0, _ablB0) = try restoreLEB(from: data, at: _cursor)
                    _r0 = (_cursor + _ablB0) ..< (_cursor + _ablB0 + Int(_abl0))
                    _cursor += _ablB0 + Int(_abl0)
                }
            }
        }

        public var items: PackedUtf8ArrayAccessor {
            if let __r = _r0 { return PackedUtf8ArrayAccessor(_data, at: __r.lowerBound) }
            return PackedUtf8ArrayAccessor(_data, at: -1)
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
