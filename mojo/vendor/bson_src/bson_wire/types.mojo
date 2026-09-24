"""BSON type bytes from bsonspec.org."""

comptime TY_DOUBLE = 0x01
comptime TY_STRING = 0x02
comptime TY_DOCUMENT = 0x03
comptime TY_ARRAY = 0x04
comptime TY_BINARY = 0x05
comptime TY_UNDEFINED = 0x06
comptime TY_OBJECTID = 0x07
comptime TY_BOOL = 0x08
comptime TY_DATETIME = 0x09
comptime TY_NULL = 0x0A
comptime TY_REGEX = 0x0B
comptime TY_DBPOINTER = 0x0C
comptime TY_CODE = 0x0D
comptime TY_SYMBOL = 0x0E
comptime TY_CODEWS = 0x0F
comptime TY_INT32 = 0x10
comptime TY_TIMESTAMP = 0x11
comptime TY_INT64 = 0x12
comptime TY_DECIMAL128 = 0x13
comptime TY_MAXKEY = 0x7F
comptime TY_MINKEY = 0xFF

comptime MAX_DOC_BYTES = 16 * 1024 * 1024
comptime MAX_DEPTH = 200

comptime BK_DOUBLE = 1
comptime BK_STRING = 2
comptime BK_DOC = 3
comptime BK_ARRAY = 4
comptime BK_BINARY = 5
comptime BK_UNDEFINED = 6
comptime BK_OID = 7
comptime BK_BOOL = 8
comptime BK_DATETIME = 9
comptime BK_NULL = 10
comptime BK_REGEX = 11
comptime BK_DBPOINTER = 12
comptime BK_CODE = 13
comptime BK_SYMBOL = 14
comptime BK_CODEWS = 15
comptime BK_INT32 = 16
comptime BK_TIMESTAMP = 17
comptime BK_INT64 = 18
comptime BK_DECIMAL = 19
comptime BK_MINKEY = 20
comptime BK_MAXKEY = 21
