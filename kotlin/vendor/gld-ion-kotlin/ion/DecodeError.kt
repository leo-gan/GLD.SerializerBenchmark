package ion

class DecodeError(val kind: Int, val offset: Int, val field: Int = 0) :
    RuntimeException("DecodeError(kind=$kind, offset=$offset, field=$field)") {
    companion object {
        const val KIND_EOF = 1
        const val KIND_SYNTAX = 2
        const val KIND_RANGE = 3
        const val KIND_UTF8 = 4
        const val KIND_ESCAPE = 5
        const val KIND_TYPE = 6
        const val KIND_DEPTH = 7
        const val KIND_SYMBOL = 8
        const val KIND_SCHEMA = 9
        const val KIND_VERSION = 10
    }
}
