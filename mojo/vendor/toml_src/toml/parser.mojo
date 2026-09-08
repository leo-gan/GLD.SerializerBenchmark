"""Parser for TOML 1.0 files.

# Why: Purpose of the Parser
The parser is the second stage of TOML parsing. It takes the token stream from
the lexer and builds structured data (nested dictionaries and lists).

Example transformation:
    Tokens: [KEY("name"), EQUALS, STRING("mojo-toml"), EOF]
    Output: {"name": "mojo-toml"}

# What: Responsibilities
- Convert token stream into nested Dict structures
- Handle all TOML value types (strings, numbers, bools, arrays, tables)
- Process dotted keys (a.b.c = value) into nested dicts
- Validate TOML syntax rules (no duplicate keys, etc.)
- Build table hierarchy from [section] headers

# How: Parser Design
The parser uses a recursive descent approach:
1. Consume tokens one by one from the lexer output
2. Build values based on token types
3. Maintain current table context for nested structures
4. Return final Dict[String, Value] structure

This keeps parsing logic separate from tokenisation, making both simpler.
"""

from std.collections import Dict, List
from std.memory import alloc
from std.math import inf, nan
from .lexer import Token, TokenKind, Lexer, Position


struct KeyValuePair(Movable, Copyable):
    """Simple struct to hold a key-value pair."""
    var key: String
    var value: TomlValue

    def __init__(out self, key: String, var value: TomlValue):
        self.key = key
        self.value = value^

    def copy(self) -> Self:
        return KeyValuePair(self.key, self.value.copy())


# Type constants for TomlValue discrimination
struct TomlValueType:
    """Type discriminator constants for TomlValue."""
    comptime STRING: Int = 0
    comptime INTEGER: Int = 1
    comptime FLOAT: Int = 2
    comptime BOOLEAN: Int = 3
    comptime ARRAY: Int = 4
    comptime TABLE: Int = 5


# TOML Value variant type - can hold any TOML value
struct TomlValue(Copyable, Movable):
    """Represents any TOML value type.

    TOML supports: strings, integers, floats, booleans, datetimes,
    arrays, and tables (nested dicts).
    """

    comptime ValuePointer = Pointer[TomlValue, MutUntrackedOrigin]

    var value_type: Int
    var string_value: String
    var int_value: Int
    var float_value: Float64
    var bool_value: Bool
    var array_value: List[Self.ValuePointer]
    var table_value: Dict[String, Self.ValuePointer]

    @staticmethod
    def box_value(var value: TomlValue) -> Self.ValuePointer:
        """Allocate a boxed TomlValue for recursive storage."""
        var ptr = alloc[TomlValue](1)
        ptr.unsafe_write(value^)
        return ptr

    @staticmethod
    def clone_boxed_value(value_ptr: Self.ValuePointer) -> Self.ValuePointer:
        """Deep-copy a boxed TomlValue into a new allocation."""
        var copied = value_ptr[].copy()
        return Self.box_value(copied^)

    def __init__(out self, value: String):
        """Create string value."""
        self.value_type = TomlValueType.STRING
        self.string_value = value
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.array_value = List[Self.ValuePointer]()
        self.table_value = Dict[String, Self.ValuePointer]()

    def __init__(out self, value: Int):
        """Create integer value."""
        self.value_type = TomlValueType.INTEGER
        self.string_value = ""
        self.int_value = value
        self.float_value = 0.0
        self.bool_value = False
        self.array_value = List[Self.ValuePointer]()
        self.table_value = Dict[String, Self.ValuePointer]()

    def __init__(out self, value: Float64):
        """Create float value."""
        self.value_type = TomlValueType.FLOAT
        self.string_value = ""
        self.int_value = 0
        self.float_value = value
        self.bool_value = False
        self.array_value = List[Self.ValuePointer]()
        self.table_value = Dict[String, Self.ValuePointer]()

    def __init__(out self, value: Bool):
        """Create boolean value."""
        self.value_type = TomlValueType.BOOLEAN
        self.string_value = ""
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = value
        self.array_value = List[Self.ValuePointer]()
        self.table_value = Dict[String, Self.ValuePointer]()

    def __init__(out self, var value: List[TomlValue]):
        """Create array value."""
        self.value_type = TomlValueType.ARRAY
        self.string_value = ""
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.array_value = List[Self.ValuePointer]()
        self.table_value = Dict[String, Self.ValuePointer]()

        for i in range(len(value)):
            var element_copy = value[i].copy()
            self.array_value.append(Self.box_value(element_copy^))

    def __init__(out self, var value: Dict[String, TomlValue]):
        """Create table (inline table) value."""
        self.value_type = TomlValueType.TABLE
        self.string_value = ""
        self.int_value = 0
        self.float_value = 0.0
        self.bool_value = False
        self.array_value = List[Self.ValuePointer]()
        self.table_value = Dict[String, Self.ValuePointer]()

        for entry in value.items():
            var entry_copy = entry.value.copy()
            self.table_value[entry.key] = Self.box_value(entry_copy^)

    def __init__(out self, *, copy: Self):
        """Create a deep copy of this value."""
        self.value_type = copy.value_type
        self.string_value = copy.string_value
        self.int_value = copy.int_value
        self.float_value = copy.float_value
        self.bool_value = copy.bool_value
        self.array_value = List[Self.ValuePointer]()
        self.table_value = Dict[String, Self.ValuePointer]()

        for i in range(len(copy.array_value)):
            self.array_value.append(Self.clone_boxed_value(copy.array_value[i]))

        for entry in copy.table_value.items():
            self.table_value[entry.key] = Self.clone_boxed_value(entry.value)

    def __deinit__(deinit self):
        """Free boxed recursive values owned by this instance."""
        for i in range(len(self.array_value)):
            var ptr = self.array_value[i]
            ptr.unsafe_deinit_pointee()
            ptr.unsafe_free()

        for entry in self.table_value.items():
            var ptr = entry.value
            ptr.unsafe_deinit_pointee()
            ptr.unsafe_free()

    def is_string(self) -> Bool:
        return self.value_type == TomlValueType.STRING

    def is_int(self) -> Bool:
        return self.value_type == TomlValueType.INTEGER

    def is_float(self) -> Bool:
        return self.value_type == TomlValueType.FLOAT

    def is_bool(self) -> Bool:
        return self.value_type == TomlValueType.BOOLEAN

    def is_array(self) -> Bool:
        return self.value_type == TomlValueType.ARRAY

    def is_table(self) -> Bool:
        return self.value_type == TomlValueType.TABLE

    def copy(self) -> Self:
        """Create a deep copy of this value."""
        return Self(copy=self)

    def as_string(self) raises -> String:
        """Get string value (raises if not a string)."""
        if not self.is_string():
            raise Error("Value is not a string")
        return self.string_value

    def as_int(self) raises -> Int:
        """Get integer value (raises if not an integer)."""
        if not self.is_int():
            raise Error("Value is not an integer")
        return self.int_value

    def as_float(self) raises -> Float64:
        """Get float value (raises if not a float)."""
        if not self.is_float():
            raise Error("Value is not a float")
        return self.float_value

    def as_bool(self) raises -> Bool:
        """Get boolean value (raises if not a boolean)."""
        if not self.is_bool():
            raise Error("Value is not a boolean")
        return self.bool_value

    def as_array(self) raises -> List[TomlValue]:
        """Get array value (raises if not an array)."""
        if not self.is_array():
            raise Error("Value is not an array")
        # Return a copy since we can't return a reference
        var result = List[TomlValue]()
        for i in range(len(self.array_value)):
            result.append(self.array_value[i][].copy())
        return result^

    def as_table(self) raises -> Dict[String, TomlValue]:
        """Get table value (raises if not a table)."""
        if not self.is_table():
            raise Error("Value is not a table")
        # Return a copy of the table
        var result = Dict[String, TomlValue]()
        for entry in self.table_value.items():
            result[entry.key] = entry.value[].copy()
        return result^


struct Parser:
    """Parser for TOML token streams.

    Converts a list of tokens from the lexer into a structured Dict.

    Usage:
        var lexer = Lexer(toml_content)
        var tokens = lexer.tokenize()
        var parser = Parser(tokens)
        var data = parser.parse()
    """

    var tokens: List[Token]
    var pos: Int
    var current_table_path: List[String]  # Track current table path for flat key storage
    var is_array_of_tables: Bool  # True if current path is an array of tables [[...]]

    def __init__(out self, var tokens: List[Token]):
        """Initialise parser with token stream.

        Args:
            tokens: List of tokens from lexer.
        """
        self.tokens = tokens^
        self.pos = 0
        self.current_table_path = List[String]()
        self.is_array_of_tables = False

    def reset(mut self, var tokens: List[Token]):
        """Reset parser state for reuse with new token stream.

        Allows reusing the same Parser instance for multiple documents,
        avoiding the overhead of creating new Parser objects.

        Args:
            tokens: New list of tokens from lexer.

        Example:
            ```mojo
            var parser = Parser(tokens1^)
            var data1 = parser.parse()

            parser.reset(tokens2^)
            var data2 = parser.parse()
            ```
        """
        self.tokens = tokens^
        self.pos = 0
        self.current_table_path = List[String]()
        self.is_array_of_tables = False

    def current(self) raises -> Token:
        """Get current token without advancing.

        Returns:
            Current token (copied).
        """
        if self.pos >= len(self.tokens):
            raise Error("Unexpected end of input")
        # Must copy since we're returning from borrowed self
        return Token(self.tokens[self.pos].kind, self.tokens[self.pos].value, self.tokens[self.pos].pos)

    def peek(self, offset: Int = 1) raises -> Token:
        """Look ahead at token.

        Args:
            offset: Number of tokens to look ahead.
        Returns:
            Token at pos + offset (copied).
        """
        var peek_pos = self.pos + offset
        if peek_pos >= len(self.tokens):
            raise Error("Unexpected end of input")
        # Must copy token explicitly
        return Token(self.tokens[peek_pos].kind, self.tokens[peek_pos].value, self.tokens[peek_pos].pos)

    def advance(mut self) raises -> Token:
        """Consume and return current token.

        Returns:
            Current token (copied).
        """
        var tok = Token(self.tokens[self.pos].kind, self.tokens[self.pos].value, self.tokens[self.pos].pos)
        self.pos += 1
        return tok^

    def expect(mut self, kind: TokenKind) raises:
        """Expect a specific token type and consume it.

        Args:
            kind: Expected token kind.
        """
        var token = self.advance()
        if token.kind != kind:
            raise Error(self.format_error("Expected specific token type but got different type", token.pos))

    def skip_newlines(mut self):
        """Skip any newline tokens."""
        while self.pos < len(self.tokens):
            try:
                var token = self.current()
                if token.kind == TokenKind.NEWLINE():
                    self.pos += 1
                else:
                    break
            except:
                break

    def skip_whitespace_and_newlines(mut self):
        """Skip whitespace and newline tokens (used inside arrays/tables)."""
        while self.pos < len(self.tokens):
            try:
                var token = self.current()
                if token.kind == TokenKind.NEWLINE() or token.kind == TokenKind.COMMENT():
                    self.pos += 1
                else:
                    break
            except:
                break

    def parse_inline_table(mut self) raises -> TomlValue:
        """Parse a TOML inline table {name = "value", port = 8080}.

        Returns:
            Table value.
        """
        # Consume opening brace
        self.expect(TokenKind.LEFT_BRACE())

        var table = Dict[String, TomlValue]()

        # Check for empty table
        var token = self.current()
        if token.kind == TokenKind.RIGHT_BRACE():
            _ = self.advance()
            return TomlValue(table^)

        # Parse key-value pairs
        while True:
            # Parse key
            token = self.current()
            if token.kind != TokenKind.KEY() and token.kind != TokenKind.STRING():
                raise Error(self.format_error("Expected key in inline table", token.pos))

            var key = token.value
            _ = self.advance()

            # Expect equals
            self.expect(TokenKind.EQUALS())

            # Parse value
            var value = self.parse_value()
            table[key] = value^

            # Check what's next
            token = self.current()

            if token.kind == TokenKind.COMMA():
                _ = self.advance()
                # Check for trailing comma (not allowed in inline tables per TOML spec)
                token = self.current()
                if token.kind == TokenKind.RIGHT_BRACE():
                    raise Error(self.format_error("Trailing comma not allowed in inline tables", token.pos))
            elif token.kind == TokenKind.RIGHT_BRACE():
                _ = self.advance()
                break
            else:
                raise Error(self.format_error("Expected comma or closing brace in inline table", token.pos))

        return TomlValue(table^)

    def parse_array(mut self) raises -> TomlValue:
        """Parse a TOML array [1, 2, 3].

        Returns:
            Array value.
        """
        # Consume opening bracket
        self.expect(TokenKind.LEFT_BRACKET())

        var elements = List[TomlValue]()

        # Skip whitespace and newlines after opening bracket
        self.skip_whitespace_and_newlines()

        # Check for empty array
        var token = self.current()
        if token.kind == TokenKind.RIGHT_BRACKET():
            _ = self.advance()
            return TomlValue(elements^)

        # Parse array elements
        while True:
            # Parse value
            var value = self.parse_value()
            elements.append(value^)

            # Skip whitespace and newlines
            self.skip_whitespace_and_newlines()

            # Check what's next
            token = self.current()

            if token.kind == TokenKind.COMMA():
                _ = self.advance()
                # Skip whitespace after comma
                self.skip_whitespace_and_newlines()
                # Check for trailing comma
                token = self.current()
                if token.kind == TokenKind.RIGHT_BRACKET():
                    _ = self.advance()
                    break
            elif token.kind == TokenKind.RIGHT_BRACKET():
                _ = self.advance()
                break
            else:
                raise Error(self.format_error("Expected comma or closing bracket in array", token.pos))

        return TomlValue(elements^)

    def parse_value(mut self) raises -> TomlValue:
        """Parse a TOML value (string, number, bool, array, or inline table).

        Returns:
            Parsed value.
        """
        var token = self.current()

        # Inline table
        if token.kind == TokenKind.LEFT_BRACE():
            return self.parse_inline_table()

        # Array
        elif token.kind == TokenKind.LEFT_BRACKET():
            return self.parse_array()

        # String
        elif token.kind == TokenKind.STRING():
            _ = self.advance()
            return TomlValue(token.value)

        # Integer
        elif token.kind == TokenKind.INTEGER():
            _ = self.advance()
            # Parse string to int, handling alternative bases
            var value = self.parse_integer(token.value)
            return TomlValue(value)

        # Float
        elif token.kind == TokenKind.FLOAT():
            _ = self.advance()
            # Handle special float values using math constants
            if token.value == "inf":
                return TomlValue(inf[DType.float64]())
            elif token.value == "-inf":
                return TomlValue(-inf[DType.float64]())
            elif token.value == "nan":
                return TomlValue(nan[DType.float64]())
            else:
                var value = atof(token.value)
                return TomlValue(Float64(value))

        # Boolean
        elif token.kind == TokenKind.BOOLEAN():
            _ = self.advance()
            var value = (token.value == "true")
            return TomlValue(value)

        else:
            raise Error(self.format_error("Unexpected token in value position", token.pos))

    def parse_integer(self, value_str: String) raises -> Int:
        """Parse integer string, handling alternative bases.

        Supports:
        - Decimal: 42, 1_000
        - Hexadecimal: 0xDEAD, 0xdead_beef
        - Octal: 0o755, 0o0755
        - Binary: 0b1101, 0b1111_0000
        Args:
            value_str: String representation of the integer.
        Returns:
            Parsed integer value.
        """
        var clean_value = value_str

        # Short values cannot have base prefixes; treat as decimal
        if clean_value.byte_length() <= 2:
            return atol(clean_value)

        # Convert to a list of single-character strings to avoid direct String indexing.
        var chars = List[String]()
        for slice in clean_value.codepoint_slices():
            chars.append(String(slice))

        # Check for hex prefix (0x or 0X)
        if chars[0] == "0" and (chars[1] == "x" or chars[1] == "X"):
            return self.parse_hex(clean_value)

        # Check for octal prefix (0o or 0O)
        elif chars[0] == "0" and (chars[1] == "o" or chars[1] == "O"):
            return self.parse_octal(clean_value)

        # Check for binary prefix (0b or 0B)
        elif chars[0] == "0" and (chars[1] == "b" or chars[1] == "B"):
            return self.parse_binary(clean_value)

        # Decimal (default)
        else:
            return atol(clean_value)

    def parse_hex(self, hex_str: String) raises -> Int:
        """Parse hexadecimal string to integer.

        Args:
            hex_str: Hexadecimal string (e.g., "0xDEAD" or "0xdead_beef").
        Returns:
            Parsed integer value.
        """
        # Skip "0x" or "0X" prefix
        var result = 0
        # Avoid direct String indexing for 0.26.1 by iterating from index 2.
        var index = 0
        for slice in hex_str.codepoint_slices():
            if index < 2:
                index += 1
                continue
            var c = String(slice)
            index += 1

            if c >= "0" and c <= "9":
                var digit = ord(c) - ord("0")
                result = result * 16 + digit
            elif c >= "a" and c <= "f":
                var digit = ord(c) - ord("a") + 10
                result = result * 16 + digit
            elif c >= "A" and c <= "F":
                var digit = ord(c) - ord("A") + 10
                result = result * 16 + digit
            elif c == "_":
                continue  # Skip underscores
            else:
                raise Error("Invalid hexadecimal digit: " + c)

        return result

    def parse_octal(self, octal_str: String) raises -> Int:
        """Parse octal string to integer.

        Args:
            octal_str: Octal string (e.g., "0o755").
        Returns:
            Parsed integer value.
        """
        # Skip "0o" or "0O" prefix
        var result = 0
        var index = 0
        for slice in octal_str.codepoint_slices():
            if index < 2:
                index += 1
                continue
            var c = String(slice)
            index += 1

            if c >= "0" and c <= "7":
                var digit = ord(c) - ord("0")
                result = result * 8 + digit
            elif c == "_":
                continue  # Skip underscores
            else:
                raise Error("Invalid octal digit: " + c)

        return result

    def parse_binary(self, binary_str: String) raises -> Int:
        """Parse binary string to integer.

        Args:
            binary_str: Binary string (e.g., "0b1101").
        Returns:
            Parsed integer value.
        """
        # Skip "0b" or "0B" prefix
        var result = 0
        var index = 0
        for slice in binary_str.codepoint_slices():
            if index < 2:
                index += 1
                continue
            var c = String(slice)
            index += 1

            if c == "0" or c == "1":
                var digit = ord(c) - ord("0")
                result = result * 2 + digit
            elif c == "_":
                continue  # Skip underscores
            else:
                raise Error("Invalid binary digit: " + c)

        return result

    def copy_path(self, path: List[String]) -> List[String]:
        """Create a copy of a path list.

        Mojo List does not support implicit copying, so we must manually copy.

        Args:
            path: Path list to copy.
        Returns:
            Copied path list.
        """
        var result = List[String]()
        for i in range(len(path)):
            result.append(path[i])
        return result^

    def format_error(self, message: String, pos: Position) -> String:
        """Format an error message with line and column information.

        Args:
            message: The error message.
            pos: Position in the source file.
        Returns:
            Formatted error message.
        """
        return message + " at line " + String(pos.line) + ", column " + String(pos.column)

    def parse_table_header(mut self) raises -> List[String]:
        """Parse a table header [section.name] and return the path.

        Returns:
            List of strings representing the table path.
        """
        # Consume opening bracket
        self.expect(TokenKind.LEFT_BRACKET())

        var path = List[String]()

        # Parse first key
        var token = self.current()
        if token.kind == TokenKind.KEY() or token.kind == TokenKind.STRING():
            path.append(token.value)
            _ = self.advance()
        else:
            raise Error(self.format_error("Expected key in table header", token.pos))

        # Parse dotted path (e.g., [a.b.c])
        while self.pos < len(self.tokens):
            token = self.current()
            if token.kind == TokenKind.DOT():
                _ = self.advance()
                token = self.current()
                if token.kind == TokenKind.KEY() or token.kind == TokenKind.STRING():
                    path.append(token.value)
                    _ = self.advance()
                else:
                    raise Error(self.format_error("Expected key after dot in table header", token.pos))
            elif token.kind == TokenKind.RIGHT_BRACKET():
                _ = self.advance()
                break
            else:
                raise Error(self.format_error("Expected dot or closing bracket in table header", token.pos))

        return path^

    def parse_array_of_tables_header(mut self) raises -> List[String]:
        """Parse an array of tables header [[section.name]] and return the path.

        Returns:
            List of strings representing the array of tables path.
        """
        # Consume opening brackets
        self.expect(TokenKind.LEFT_BRACKET())
        self.expect(TokenKind.LEFT_BRACKET())

        var path = List[String]()

        # Parse first key
        var token = self.current()
        if token.kind == TokenKind.KEY() or token.kind == TokenKind.STRING():
            path.append(token.value)
            _ = self.advance()
        else:
            raise Error(self.format_error("Expected key in array of tables header", token.pos))

        # Parse dotted path (e.g., [[fruit.variety]])
        while self.pos < len(self.tokens):
            token = self.current()
            if token.kind == TokenKind.DOT():
                _ = self.advance()
                token = self.current()
                if token.kind == TokenKind.KEY() or token.kind == TokenKind.STRING():
                    path.append(token.value)
                    _ = self.advance()
                else:
                    raise Error(self.format_error("Expected key after dot in array of tables header", token.pos))
            elif token.kind == TokenKind.RIGHT_BRACKET():
                _ = self.advance()
                # Expect second closing bracket
                token = self.current()
                if token.kind == TokenKind.RIGHT_BRACKET():
                    _ = self.advance()
                    break
                else:
                    raise Error(self.format_error("Expected closing ]] for array of tables", token.pos))
            else:
                raise Error(self.format_error("Expected dot or closing bracket in array of tables header", token.pos))

        return path^

    def ensure_table_path(mut self, result: Dict[String, TomlValue], path: List[String]) raises -> Dict[String, TomlValue]:
        """Ensure a nested table path exists, creating tables as needed.

        Args:
            result: Root dictionary.
            path: List of keys forming the path (e.g., ["database", "primary"]).
        Returns:
            New dictionary with path ensured.
        """
        if len(path) == 0:
            # Copy and return
            var copy = Dict[String, TomlValue]()
            for entry in result.items():
                copy[entry.key] = entry.value.copy()
            return copy^

        # Copy result
        var new_result = Dict[String, TomlValue]()
        for entry in result.items():
            new_result[entry.key] = entry.value.copy()

        # Check/create first level
        var first_key = path[0]
        if not new_result.__contains__(first_key):
            var new_table = Dict[String, TomlValue]()
            new_result[first_key] = TomlValue(new_table^)
        elif not new_result[first_key].is_table():
            raise Error("Cannot redefine key as table - key exists but is not a table: " + first_key)

        # For paths longer than 1, recursively ensure nested tables
        if len(path) > 1:
            # Get the current table, modify it, put it back
            var current_table = new_result[first_key].as_table()
            var remaining_path = List[String]()
            for i in range(1, len(path)):
                remaining_path.append(path[i])
            current_table = self.ensure_table_path(current_table^, remaining_path)
            new_result[first_key] = TomlValue(current_table^)

        return new_result^

    def ensure_array_of_tables_path(mut self, result: Dict[String, TomlValue], path: List[String]) raises -> Dict[String, TomlValue]:
        """Ensure an array of tables path exists, creating or appending as needed.

        For [[products]], this creates or appends to the 'products' array.
        For [[fruit.variety]], this creates nested tables and appends to the 'variety' array.

        Args:
            result: Root dictionary.
            path: List of keys forming the path (e.g., ["fruit", "variety"]).
        Returns:
            New dictionary with array element appended.
        """
        if len(path) == 0:
            raise Error("Array of tables path cannot be empty")

        # Copy result
        var new_result = Dict[String, TomlValue]()
        for entry in result.items():
            new_result[entry.key] = entry.value.copy()

        # Handle simple case: [[products]]
        if len(path) == 1:
            var key = path[0]
            if not new_result.__contains__(key):
                # Create new array with empty table
                var new_array = List[TomlValue]()
                var empty_table = Dict[String, TomlValue]()
                new_array.append(TomlValue(empty_table^))
                new_result[key] = TomlValue(new_array^)
            elif new_result[key].is_array():
                # Append new empty table to existing array
                var arr = new_result[key].as_array()
                var empty_table = Dict[String, TomlValue]()
                arr.append(TomlValue(empty_table^))
                new_result[key] = TomlValue(arr^)
            else:
                raise Error("Cannot redefine key as array of tables - key exists but is not an array: " + key)
            return new_result^

        # Handle nested case: [[fruit.variety]]
        # The first key might be an array (e.g., fruit in [[fruit.variety]])
        # We need to operate on the LAST element of that array
        var first_key = path[0]

        if len(path) == 2:
            # Two-level path: [[parent.array]]
            # Check if first_key is an array or table
            if not new_result.__contains__(first_key):
                # Doesn't exist - create as table
                var new_table = Dict[String, TomlValue]()
                new_result[first_key] = TomlValue(new_table^)

            var array_key = path[1]

            if new_result[first_key].is_table():
                # Normal case: [[parent.array]] where parent is a table
                var parent_table = new_result[first_key].as_table()

                if not parent_table.__contains__(array_key):
                    # Create new array with empty table
                    var new_array = List[TomlValue]()
                    var empty_table = Dict[String, TomlValue]()
                    new_array.append(TomlValue(empty_table^))
                    parent_table[array_key] = TomlValue(new_array^)
                elif parent_table[array_key].is_array():
                    # Append new empty table to existing array
                    var arr = parent_table[array_key].as_array()
                    var empty_table = Dict[String, TomlValue]()
                    arr.append(TomlValue(empty_table^))
                    parent_table[array_key] = TomlValue(arr^)
                else:
                    raise Error("Cannot redefine key as array of tables - key exists but is not an array: " + array_key)

                new_result[first_key] = TomlValue(parent_table^)
            elif new_result[first_key].is_array():
                # Special case: [[fruit.variety]] where fruit is already an array
                # We need to add variety array to the LAST element of fruit array
                var parent_array = new_result[first_key].as_array()
                if len(parent_array) == 0:
                    raise Error("Cannot add nested array to empty array: " + first_key)

                # Get last element of parent array (should be a table)
                var last_element = parent_array[len(parent_array) - 1].as_table()

                if not last_element.__contains__(array_key):
                    # Create new array with empty table
                    var new_array = List[TomlValue]()
                    var empty_table = Dict[String, TomlValue]()
                    new_array.append(TomlValue(empty_table^))
                    last_element[array_key] = TomlValue(new_array^)
                elif last_element[array_key].is_array():
                    # Append new empty table to existing array
                    var arr = last_element[array_key].as_array()
                    var empty_table = Dict[String, TomlValue]()
                    arr.append(TomlValue(empty_table^))
                    last_element[array_key] = TomlValue(arr^)
                else:
                    raise Error("Cannot redefine key as array of tables - key exists but is not an array: " + array_key)

                # Update the last element in parent array
                parent_array[len(parent_array) - 1] = TomlValue(last_element^)
                new_result[first_key] = TomlValue(parent_array^)
            else:
                raise Error("Cannot use non-table/non-array as parent for array of tables: " + first_key)

            return new_result^
        else:
            # More than 2 levels deep - use recursive approach
            # Ensure first level exists as table
            if not new_result.__contains__(first_key):
                var new_table = Dict[String, TomlValue]()
                new_result[first_key] = TomlValue(new_table^)
            elif not new_result[first_key].is_table():
                raise Error("Cannot redefine key as table - key exists but is not a table: " + first_key)

            # Get the nested table and recurse
            var nested_table = new_result[first_key].as_table()
            var remaining_path = List[String]()
            for i in range(1, len(path)):
                remaining_path.append(path[i])
            nested_table = self.ensure_array_of_tables_path(nested_table^, remaining_path)
            new_result[first_key] = TomlValue(nested_table^)
            return new_result^

    def set_table_at_path(mut self, result: Dict[String, TomlValue], path: List[String], var table: Dict[String, TomlValue]) raises -> Dict[String, TomlValue]:
        """Set a table at a specific path (helper for array of tables).

        Args:
            result: Root dictionary.
            path: Path to where the table should be set.
            table: The table to set.
        Returns:
            New dictionary with table set at path.
        """
        if len(path) == 0:
            return table^

        var new_result = Dict[String, TomlValue]()
        for entry in result.items():
            new_result[entry.key] = entry.value.copy()

        if len(path) == 1:
            new_result[path[0]] = TomlValue(table^)
            return new_result^
        else:
            var first_key = path[0]
            var nested_table = new_result[first_key].as_table()
            var remaining_path = List[String]()
            for i in range(1, len(path)):
                remaining_path.append(path[i])
            nested_table = self.set_table_at_path(nested_table^, remaining_path, table^)
            new_result[first_key] = TomlValue(nested_table^)
            return new_result^

    def merge_tables(self, existing: Dict[String, TomlValue], var new_table: TomlValue, key: String) raises -> Dict[String, TomlValue]:
        """Merge a new table value into existing table, checking for conflicts.

        Args:
            existing: Existing table.
            new_table: New table to merge in.
            key: The key being set (for error messages).
        Returns:
            Merged table.
        """
        if not new_table.is_table():
            raise Error("Cannot merge non-table value into table for key: " + key)

        var result = Dict[String, TomlValue]()
        # Copy existing entries
        for entry in existing.items():
            result[entry.key] = entry.value.copy()

        # Merge new entries
        var new_entries = new_table.as_table()
        for entry in new_entries.items():
            if result.__contains__(entry.key):
                # Key exists - check if both are tables for recursive merge
                if result[entry.key].is_table() and entry.value.is_table():
                    # Recursively merge nested tables
                    var merged = self.merge_tables(result[entry.key].as_table(), entry.value.copy(), entry.key)
                    result[entry.key] = TomlValue(merged^)
                else:
                    # Duplicate key error - not both tables
                    raise Error("Duplicate key: " + entry.key)
            else:
                result[entry.key] = entry.value.copy()

        return result^

    def set_in_table_path(mut self, result: Dict[String, TomlValue], path: List[String], key: String, var value: TomlValue) raises -> Dict[String, TomlValue]:
        """Set a key-value pair at a specific table path with duplicate key detection.

        Args:
            result: Root dictionary.
            path: Path to the target table.
            key: Key to set.
            value: Value to set.
        Returns:
            New dictionary with value set.
        """
        # Ensure the path exists first
        var new_result = self.ensure_table_path(result, path)

        if len(path) == 0:
            # Set at root level - check for duplicates
            if new_result.__contains__(key):
                # If both are tables, merge them (for dotted keys)
                if new_result[key].is_table() and value.is_table():
                    var merged = self.merge_tables(new_result[key].as_table(), value^, key)
                    new_result[key] = TomlValue(merged^)
                    return new_result^
                else:
                    raise Error("Duplicate key: " + key)
            new_result[key] = value^
            return new_result^
        else:
            # Navigate to target table and set
            var table = new_result[path[0]].as_table()
            if len(path) == 1:
                # Check for duplicates at this level
                if table.__contains__(key):
                    # If both are tables, merge them (for dotted keys)
                    if table[key].is_table() and value.is_table():
                        var merged = self.merge_tables(table[key].as_table(), value^, key)
                        table[key] = TomlValue(merged^)
                    else:
                        raise Error("Duplicate key: " + key)
                else:
                    table[key] = value^
                new_result[path[0]] = TomlValue(table^)
            else:
                # Recurse for deeper paths
                var remaining_path = List[String]()
                for i in range(1, len(path)):
                    remaining_path.append(path[i])
                table = self.set_in_table_path(table^, remaining_path, key, value^)
                new_result[path[0]] = TomlValue(table^)
            return new_result^

    def set_in_array_of_tables_path(mut self, result: Dict[String, TomlValue], path: List[String], key: String, var value: TomlValue) raises -> Dict[String, TomlValue]:
        """Set a key-value pair in the last element of an array of tables.

        Args:
            result: Root dictionary.
            path: Path to the array of tables.
            key: Key to set in the last array element.
            value: Value to set.
        Returns:
            New dictionary with value set in the last array element.
        """
        if len(path) == 0:
            raise Error("Array of tables path cannot be empty")

        var new_result = Dict[String, TomlValue]()
        for entry in result.items():
            new_result[entry.key] = entry.value.copy()

        # Navigate to the array location
        if len(path) == 1:
            # Simple case: [[products]]
            var array_key = path[0]
            if not new_result.__contains__(array_key) or not new_result[array_key].is_array():
                raise Error("Expected array of tables at: " + array_key)

            var arr = new_result[array_key].as_array()
            if len(arr) == 0:
                raise Error("Array of tables is empty")

            # Get last element (the current table being filled)
            var last_table = arr[len(arr) - 1].as_table()

            # Check for duplicates
            if last_table.__contains__(key):
                # If both are tables, merge them (for dotted keys)
                if last_table[key].is_table() and value.is_table():
                    var merged = self.merge_tables(last_table[key].as_table(), value^, key)
                    last_table[key] = TomlValue(merged^)
                else:
                    raise Error("Duplicate key: " + key)
            else:
                last_table[key] = value^

            # Update array with modified table
            arr[len(arr) - 1] = TomlValue(last_table^)
            new_result[array_key] = TomlValue(arr^)
            return new_result^
        else:
            # Nested case: [[fruit.variety]] - use recursion
            var first_key = path[0]

            if len(path) == 2:
                # Two-level path: [[parent.array]]
                if not new_result.__contains__(first_key):
                    raise Error("Key does not exist: " + first_key)

                var array_key = path[1]

                if new_result[first_key].is_table():
                    # Normal case: parent is a table
                    var parent_table = new_result[first_key].as_table()

                    if not parent_table.__contains__(array_key) or not parent_table[array_key].is_array():
                        raise Error("Expected array of tables at: " + array_key)

                    var arr = parent_table[array_key].as_array()
                    if len(arr) == 0:
                        raise Error("Array of tables is empty")

                    # Get last element and set the key
                    var last_table = arr[len(arr) - 1].as_table()

                    # Check for duplicates
                    if last_table.__contains__(key):
                        if last_table[key].is_table() and value.is_table():
                            var merged = self.merge_tables(last_table[key].as_table(), value^, key)
                            last_table[key] = TomlValue(merged^)
                        else:
                            raise Error("Duplicate key: " + key)
                    else:
                        last_table[key] = value^

                    # Update array with modified table
                    arr[len(arr) - 1] = TomlValue(last_table^)
                    parent_table[array_key] = TomlValue(arr^)
                    new_result[first_key] = TomlValue(parent_table^)
                elif new_result[first_key].is_array():
                    # Special case: [[fruit.variety]] where fruit is an array
                    # We need to set in the last element of fruit's variety array
                    var parent_array = new_result[first_key].as_array()
                    if len(parent_array) == 0:
                        raise Error("Array is empty: " + first_key)

                    # Get last element of parent array
                    var last_parent_element = parent_array[len(parent_array) - 1].as_table()

                    if not last_parent_element.__contains__(array_key) or not last_parent_element[array_key].is_array():
                        raise Error("Expected array of tables at: " + array_key)

                    var arr = last_parent_element[array_key].as_array()
                    if len(arr) == 0:
                        raise Error("Array of tables is empty")

                    # Get last element of the nested array and set the key
                    var last_table = arr[len(arr) - 1].as_table()

                    # Check for duplicates
                    if last_table.__contains__(key):
                        if last_table[key].is_table() and value.is_table():
                            var merged = self.merge_tables(last_table[key].as_table(), value^, key)
                            last_table[key] = TomlValue(merged^)
                        else:
                            raise Error("Duplicate key: " + key)
                    else:
                        last_table[key] = value^

                    # Update nested structures
                    arr[len(arr) - 1] = TomlValue(last_table^)
                    last_parent_element[array_key] = TomlValue(arr^)
                    parent_array[len(parent_array) - 1] = TomlValue(last_parent_element^)
                    new_result[first_key] = TomlValue(parent_array^)
                else:
                    raise Error("Expected table or array at: " + first_key)

                return new_result^
            else:
                # More than 2 levels deep - use recursion
                if not new_result.__contains__(first_key) or not new_result[first_key].is_table():
                    raise Error("Expected table at: " + first_key)

                var nested_table = new_result[first_key].as_table()
                var remaining_path = List[String]()
                for i in range(1, len(path)):
                    remaining_path.append(path[i])
                nested_table = self.set_in_array_of_tables_path(nested_table^, remaining_path, key, value^)
                new_result[first_key] = TomlValue(nested_table^)
                return new_result^

    def create_nested_value_from_dotted_key(self, key_parts: List[String], var value: TomlValue) raises -> TomlValue:
        """Convert dotted key into nested table structure.

        For example: a.b.c = value becomes {a: {b: {c: value}}}
        Args:
            key_parts: List of key components from dotted key.
            value: The final value to set.
        Returns:
            TomlValue representing nested table structure.
        """
        if len(key_parts) == 1:
            return value^

        # Build from the innermost level outward
        var result = value^
        for i in range(len(key_parts) - 1, 0, -1):
            var table = Dict[String, TomlValue]()
            table[key_parts[i]] = result^
            result = TomlValue(table^)

        return result^

    def parse_key_value_pair(mut self) raises -> KeyValuePair:
        """Parse a key = value pair and return the key and value.

        Returns:
            KeyValuePair containing the parsed key and value.
        """
        # Parse key (can be dotted: a.b.c)
        var key_parts = List[String]()

        # First key part
        var token = self.current()
        if token.kind == TokenKind.KEY() or token.kind == TokenKind.STRING():
            key_parts.append(token.value)
            _ = self.advance()
        else:
            raise Error(self.format_error("Expected key", token.pos))

        # Handle dotted keys (a.b.c)
        while self.pos < len(self.tokens):
            try:
                token = self.current()
                if token.kind == TokenKind.DOT():
                    _ = self.advance()
                    token = self.current()
                    if token.kind == TokenKind.KEY() or token.kind == TokenKind.STRING():
                        key_parts.append(token.value)
                        _ = self.advance()
                    else:
                        raise Error(self.format_error("Expected key after dot", token.pos))
                else:
                    break
            except:
                break

        # Expect equals sign
        self.expect(TokenKind.EQUALS())

        # Parse value
        var value = self.parse_value()

        # For simple key (not dotted), return it
        if len(key_parts) == 1:
            return KeyValuePair(key_parts[0], value^)
        else:
            # Create nested table structure for dotted keys
            # a.b.c = value becomes: return ("a", {b: {c: value}})
            var nested_value = self.create_nested_value_from_dotted_key(key_parts, value^)
            return KeyValuePair(key_parts[0], nested_value^)

    def parse(mut self) raises -> Dict[String, TomlValue]:
        """Parse the entire TOML document.

        Returns:
            Dictionary containing all TOML data with nested table structures.
        """
        var result = Dict[String, TomlValue]()

        self.skip_newlines()

        while self.pos < len(self.tokens):
            var token = self.current()

            # EOF
            if token.kind == TokenKind.EOF():
                break

            # Comment (skip)
            elif token.kind == TokenKind.COMMENT():
                _ = self.advance()
                self.skip_newlines()

            # Newline (skip)
            elif token.kind == TokenKind.NEWLINE():
                self.skip_newlines()

            # Table header [section] or array of tables [[section]]
            elif token.kind == TokenKind.LEFT_BRACKET():
                # Check if it's an array of tables [[ ]]
                var is_array = False
                try:
                    var next_token = self.peek()
                    if next_token.kind == TokenKind.LEFT_BRACKET():
                        is_array = True
                except:
                    pass

                if is_array:
                    # Parse array of tables header [[array]]
                    self.current_table_path = self.parse_array_of_tables_header()
                    self.is_array_of_tables = True
                    # Copy path (Mojo List doesn't support implicit copy)
                    var path_copy = self.copy_path(self.current_table_path)
                    # Append new element to the array
                    var updated_result = self.ensure_array_of_tables_path(result, path_copy)
                    result = updated_result^
                else:
                    # Parse regular table header and update current path
                    self.current_table_path = self.parse_table_header()
                    self.is_array_of_tables = False
                    # Copy path (Mojo List doesn't support implicit copy)
                    var path_copy = self.copy_path(self.current_table_path)
                    # Ensure the table path exists in result
                    var updated_result = self.ensure_table_path(result, path_copy)
                    result = updated_result^

                self.skip_newlines()

            # Key-value pair
            elif token.kind == TokenKind.KEY() or token.kind == TokenKind.STRING():
                # Parse the key-value pair
                var pair = self.parse_key_value_pair()

                # Must copy key and value to avoid partial destruction.
                # Mojo's ownership system prevents consuming pair.value while pair.key is still needed.
                # The copy allows us to safely extract both fields from the struct.
                var parsed_key = pair.key
                var parsed_value = pair.value.copy()

                # Copy path (Mojo List doesn't support implicit copy)
                var path_copy = self.copy_path(self.current_table_path)

                # Set the value - use array method if we're in an array of tables
                var updated_result: Dict[String, TomlValue]
                if self.is_array_of_tables:
                    updated_result = self.set_in_array_of_tables_path(result, path_copy, parsed_key, parsed_value^)
                else:
                    updated_result = self.set_in_table_path(result, path_copy, parsed_key, parsed_value^)
                result = updated_result^

                self.skip_newlines()

            else:
                var token = self.current()
                raise Error(self.format_error("Unexpected token at top level", token.pos))

        return result^
def parse(content: String) raises -> Dict[String, TomlValue]:
    """Parse TOML content from a string.

    This is the main public API for parsing TOML.

    Args:
        content: TOML content as a string.
    Returns:
        Dictionary containing parsed TOML data.

    Example:
        ```mojo
        var data = parse('[package]\\nname = "mojo-toml"')
        print(data["name"].as_string())  # Prints: mojo-toml
        ```
    """
    var lexer = Lexer(content)
    var tokens = lexer.tokenize()
    var parser = Parser(tokens^)
    return parser.parse()
