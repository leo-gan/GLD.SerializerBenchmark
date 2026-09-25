import Foundation

extension TelemetryFrozenPackedGraph {

    public struct TelemetryAccessor {
        private let _data: Foundation.Data
        internal let _nodeStart: Int
        private var _r0: Range<Int>? = nil  // source
        private var _v1: Int64? = nil  // ts
        private var _r2: Range<Int>? = nil  // tags
        private var _r3: Range<Int>? = nil  // values

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
                    _v1 = try Int64.restore(from: data, at: _cur); _cur += 8
                } else {
                    let (_v, _vB) = try restoreLEB(from: data, at: _cur)
                    _v1 = Int64(_v.fromZigZag); _cur += _vB
                }
            }
            let (_abl2, _ablB2) = try restoreLEB(from: data, at: _cur)
            _r2 = (_cur + _ablB2) ..< (_cur + _ablB2 + Int(_abl2))
            _cur += _ablB2 + Int(_abl2)
            let (_abl3, _ablB3) = try restoreLEB(from: data, at: _cur)
            _r3 = (_cur + _ablB3) ..< (_cur + _ablB3 + Int(_abl3))
            _cur += _ablB3 + Int(_abl3)
        }

        public var source: String? {
            guard let r = _r0 else { return nil }
            return _dagrUTF8(_data[r])
        }

        public var ts: Int64? { return _v1 }

        public var tags: PackedUtf8ArrayAccessor {
            if let __r = _r2 { return PackedUtf8ArrayAccessor(_data, at: __r.lowerBound) }
            return PackedUtf8ArrayAccessor(_data, at: -1)
        }

        public var values: PackedF64ArrayAccessor {
            if let __r = _r3 { return PackedF64ArrayAccessor(_data, at: __r.lowerBound) }
            return PackedF64ArrayAccessor(_data, at: -1)
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
