"""Lexer for TOML 1.0 files.

# Why: Purpose of the Lexer
The lexer (tokeniser) is the first stage of TOML parsing. It converts raw text into
a stream of meaningful tokens, making it easier for the parser to understand structure.

Example transformation:
    Input:  'name = "mojo-toml"  # A TOML parser'
    Output: [KEY("name"), EQUALS, STRING("mojo-toml"), COMMENT("A TOML parser")]

# What: Responsibilities
- Break TOML text into atomic units (tokens)
- Identify token types (strings, numbers, punctuation, etc.)
- Handle string escape sequences (\\n, \\t, etc.)
- Track line/column positions for error messages
- Support multiline strings and comments

# How: Lexer Design
The lexer uses a character-by-character scanner with lookahead:
1. Read current character
2. Determine token type (string? number? punctuation?)
3. Consume characters until token complete
4. Emit token with type, value, and position
5. Repeat until EOF

This design keeps the parser simple—it works with high-level tokens rather than
raw characters, making TOML syntax rules easier to implement.

# TOML-Specific Handling
- Multiline strings: Triple quotes \"\"\" or '''
- Number formats: 1_000 (underscores), 1e10 (scientific), inf/nan (special floats)
- String types: Basic "text" (with escapes) vs Literal 'raw' (no escapes)
- Comments: # to end of line (not inside strings)
"""

from std.collections import List


struct Position(Copyable, Movable):
    """Position in the source file (line and column).

    Used for error messages to show users exactly where parsing failed.
    Example: "Error at line 5, column 12: unexpected character"
    """
    var line: Int
    var column: Int

    def __init__(out self, line: Int, column: Int):
        self.line = line
        self.column = column


struct TokenKind(Copyable, Movable):
    """Token types for TOML lexer.

    Each token represents a meaningful unit in TOML syntax.
    Static methods replace deprecated `alias` keyword.
    """
    var _value: Int

    def __init__(out self, value: Int):
        self._value = value

    # Special tokens
    @staticmethod
    def EOF() -> TokenKind:
        """End of file marker."""
        return TokenKind(0)

    @staticmethod
    def NEWLINE() -> TokenKind:
        """Line break (significant in TOML for separating key-value pairs)."""
        return TokenKind(1)

    @staticmethod
    def WHITESPACE() -> TokenKind:
        """Spaces and tabs (usually skipped)."""
        return TokenKind(2)

    @staticmethod
    def COMMENT() -> TokenKind:
        """Comment text after # symbol."""
        return TokenKind(3)

    # Literal values
    @staticmethod
    def STRING() -> TokenKind:
        """String literal: "basic" or 'literal'."""
        return TokenKind(10)

    @staticmethod
    def INTEGER() -> TokenKind:
        """Integer: 42, +17, -5, 1_000."""
        return TokenKind(11)

    @staticmethod
    def FLOAT() -> TokenKind:
        """Float: 3.14, 1e10, inf, nan."""
        return TokenKind(12)

    @staticmethod
    def BOOLEAN() -> TokenKind:
        """Boolean: true or false."""
        return TokenKind(13)

    @staticmethod
    def DATETIME() -> TokenKind:
        """ISO 8601 datetime (parsed as string in v0.1.0)."""
        return TokenKind(14)

    # Identifiers
    @staticmethod
    def KEY() -> TokenKind:
        """Unquoted key name."""
        return TokenKind(20)

    # Punctuation (structural elements)
    @staticmethod
    def EQUALS() -> TokenKind:
        """Assignment operator: =."""
        return TokenKind(30)

    @staticmethod
    def DOT() -> TokenKind:
        """Dotted key separator: a.b.c."""
        return TokenKind(31)

    @staticmethod
    def COMMA() -> TokenKind:
        """Array/inline table separator: ,."""
        return TokenKind(32)

    @staticmethod
    def LEFT_BRACKET() -> TokenKind:
        """Array start or table header: [."""
        return TokenKind(33)

    @staticmethod
    def RIGHT_BRACKET() -> TokenKind:
        """Array end or table header close: ]."""
        return TokenKind(34)

    @staticmethod
    def LEFT_BRACE() -> TokenKind:
        """Inline table start: {."""
        return TokenKind(35)

    @staticmethod
    def RIGHT_BRACE() -> TokenKind:
        """Inline table end: }."""
        return TokenKind(36)

    def __eq__(self, other: TokenKind) -> Bool:
        return self._value == other._value

    def __ne__(self, other: TokenKind) -> Bool:
        return self._value != other._value


struct Token(Copyable, Movable):
    """A token in the TOML input stream.

    Represents a single meaningful unit of TOML syntax with its type,
    content, and location in the source file.
    """
    var kind: TokenKind
    var value: String  # The actual text content
    var pos: Position  # Where it appears in the file

    def __init__(out self, kind: TokenKind, value: String, pos: Position):
        self.kind = kind.copy()
        self.value = value
        self.pos = pos.copy()


struct Lexer:
    """Tokeniser for TOML input.

    The lexer scans TOML text character-by-character and produces a stream
    of tokens. It handles:
    - String parsing (with escape sequences)
    - Number formats (integers, floats, scientific notation)
    - Comments (# to end of line)
    - Whitespace management
    - Position tracking for error messages

    Usage:
        var lexer = Lexer("name = 'value'")
        var tokens = lexer.tokenize()  # Returns List[Token]
    """

    var input: String
    var chars: List[String]
    var pos: Int      # Current position in input (index into chars)
    var line: Int     # Current line number (1-indexed)
    var column: Int   # Current column number (1-indexed)

    def __init__(out self, input: String):
        """Initialise lexer with TOML input.

        Args:
            input: TOML content to tokenise.
        """
        self.input = input
        self.chars = List[String]()
        # Build a list of single-character strings using codepoint_slices to
        # avoid relying on String.__iter__ semantics in Mojo 0.26.1.
        for slice in input.codepoint_slices():
            self.chars.append(String(slice))
        self.pos = 0
        self.line = 1
        self.column = 1

    def current(self) -> String:
        """Get current character without advancing.

        Returns:
            Current character or empty string if at EOF.
        """
        if self.pos >= len(self.chars):
            return ""
        return self.chars[self.pos]

    def peek(self, offset: Int = 1) -> String:
        """Look ahead at character without consuming it.

        Used for lookahead decisions, e.g. detecting triple quotes.

        Args:
            offset: Number of characters to look ahead (default: 1).

        Returns:
            Character at pos + offset or empty string if out of bounds.
        """
        var peek_pos = self.pos + offset
        if peek_pos >= len(self.chars):
            return ""
        return self.chars[peek_pos]

    def advance(mut self) -> String:
        """Consume and return current character.

        Advances position and updates line/column tracking for error messages.

        Returns:
            Current character or empty string if at EOF.
        """
        if self.pos >= len(self.chars):
            return ""

        var c = self.chars[self.pos]
        self.pos += 1

        if c == "\n":
            self.line += 1
            self.column = 1
        else:
            self.column += 1

        return c

    def skip_whitespace(mut self):
        """Skip whitespace characters (space, tab) but not newlines.

        Newlines are significant in TOML for separating key-value pairs,
        so we preserve them as NEWLINE tokens.
        """
        while self.pos < len(self.chars):
            var c = self.current()
            if c == " " or c == "\t":
                _ = self.advance()
            else:
                break

    def read_comment(mut self) raises -> Token:
        """Read a comment starting with #.

        Comments run from # to end of line. They can appear after values:
            name = "value"  # This is a comment

        Returns:
            Comment token (excluding the # character).
        """
        var start_pos = Position(self.line, self.column)
        _ = self.advance()  # Skip #

        var comment = String("")
        while self.pos < len(self.chars):
            var c = self.current()
            if c == "\n":
                break
            comment += self.advance()

        return Token(TokenKind.COMMENT(), comment, start_pos)

    def read_string(mut self) raises -> Token:
        """Read a quoted string (basic or literal).

        TOML supports two string types:
        1. Basic strings: "text" - supports escape sequences (\\n, \\t, etc.)
        2. Literal strings: 'raw' - no escape processing

        Both support multiline variants with triple quotes:
        - \"\"\"multiline basic\"\"\"
        - '''multiline literal'''

        Returns:
            String token with processed content (escapes handled).
        """
        var start_pos = Position(self.line, self.column)
        var quote_char = self.current()
        _ = self.advance()  # Skip opening quote

        # Check for multiline (triple quotes)
        var is_multiline = False
        if self.current() == quote_char and self.peek(1) == quote_char:
            is_multiline = True
            _ = self.advance()  # Skip second quote
            _ = self.advance()  # Skip third quote

        var value = String("")
        var is_literal = (quote_char == "'")

        while self.pos < len(self.chars):
            var c = self.current()

            # Check for closing quotes
            if is_multiline:
                if c == quote_char and self.peek(1) == quote_char and self.peek(2) == quote_char:
                    _ = self.advance()  # Skip first quote
                    _ = self.advance()  # Skip second quote
                    _ = self.advance()  # Skip third quote
                    break
            else:
                if c == quote_char:
                    _ = self.advance()  # Skip closing quote
                    break

            # Handle escape sequences in basic strings only
            if not is_literal and c == "\\":
                _ = self.advance()
                var next_c = self.current()
                if next_c == "n":
                    value += "\n"
                    _ = self.advance()
                elif next_c == "t":
                    value += "\t"
                    _ = self.advance()
                elif next_c == "r":
                    value += "\r"
                    _ = self.advance()
                elif next_c == "\\":
                    value += "\\\\"
                    _ = self.advance()
                elif next_c == '"':
                    value += '"'
                    _ = self.advance()
                elif next_c == "'":
                    value += "'"
                    _ = self.advance()
                elif next_c == "e":
                    # TOML 1.1: \e for escape character (U+001B)
                    value += String(chr(0x1B))
                    _ = self.advance()
                elif next_c == "x":
                    # TOML 1.1: \xHH for codepoints <255
                    _ = self.advance()  # Skip 'x'
                    var hex1 = self.current()
                    if not self.is_hex_digit(hex1):
                        raise Error("Invalid \\x escape: expected hex digit")
                    _ = self.advance()
                    var hex2 = self.current()
                    if not self.is_hex_digit(hex2):
                        raise Error("Invalid \\x escape: expected two hex digits")
                    _ = self.advance()
                    # Convert hex to integer
                    var hex_str = hex1 + hex2
                    var codepoint = self.hex_to_int(hex_str)
                    value += String(chr(codepoint))
                else:
                    # Invalid escape - keep backslash
                    value += "\\"
            else:
                value += self.advance()

        return Token(TokenKind.STRING(), value, start_pos)

    def read_number(mut self) raises -> Token:
        """Read a number (integer or float).

        TOML supports rich number formats:
        - Integers: 42, +17, -5
        - Hex: 0xDEAD, 0xdead_beef
        - Octal: 0o755, 0o0755
        - Binary: 0b1101, 0b1111_0000
        - Underscores: 1_000, 5_349_221
        - Floats: 3.14, 1e10, 6.022e23
        - Special: inf, -inf, nan

        Returns:
            INTEGER or FLOAT token.
        """
        var start_pos = Position(self.line, self.column)
        var value = String("")
        var is_float = False

        # Handle sign
        var c = self.current()
        if c == "+" or c == "-":
            value += self.advance()

        # Handle special float values (inf, nan)
        if self.current() == "i" and self.peek(1) == "n" and self.peek(2) == "f":
            value += self.advance()  # i
            value += self.advance()  # n
            value += self.advance()  # f
            return Token(TokenKind.FLOAT(), value, start_pos)
        elif self.current() == "n" and self.peek(1) == "a" and self.peek(2) == "n":
            value += self.advance()  # n
            value += self.advance()  # a
            value += self.advance()  # n
            return Token(TokenKind.FLOAT(), value, start_pos)

        # Check for alternative number bases (hex, octal, binary)
        if self.current() == "0":
            var next_char = self.peek(1)

            # Hexadecimal: 0x or 0X
            if next_char == "x" or next_char == "X":
                value += self.advance()  # 0
                value += self.advance()  # x
                # Read hex digits and underscores
                while self.pos < len(self.chars):
                    c = self.current()
                    if (c >= "0" and c <= "9") or (c >= "a" and c <= "f") or (c >= "A" and c <= "F"):
                        value += self.advance()
                    elif c == "_":
                        _ = self.advance()  # Skip underscores
                    else:
                        break
                return Token(TokenKind.INTEGER(), value, start_pos)

            # Octal: 0o or 0O
            elif next_char == "o" or next_char == "O":
                value += self.advance()  # 0
                value += self.advance()  # o
                # Read octal digits and underscores
                while self.pos < len(self.chars):
                    c = self.current()
                    if c >= "0" and c <= "7":
                        value += self.advance()
                    elif c == "_":
                        _ = self.advance()  # Skip underscores
                    else:
                        break
                return Token(TokenKind.INTEGER(), value, start_pos)

            # Binary: 0b or 0B
            elif next_char == "b" or next_char == "B":
                value += self.advance()  # 0
                value += self.advance()  # b
                # Read binary digits and underscores
                while self.pos < len(self.chars):
                    c = self.current()
                    if c == "0" or c == "1":
                        value += self.advance()
                    elif c == "_":
                        _ = self.advance()  # Skip underscores
                    else:
                        break
                return Token(TokenKind.INTEGER(), value, start_pos)

        # Read decimal digits and separators
        while self.pos < len(self.chars):
            c = self.current()

            if c >= "0" and c <= "9":
                value += self.advance()
            elif c == "_":
                # Underscores for readability: 1_000_000
                _ = self.advance()
            elif c == ".":
                is_float = True
                value += self.advance()
            elif c == "e" or c == "E":
                # Scientific notation: 1e10, 6.022e23
                is_float = True
                value += self.advance()
                # Handle exponent sign
                if self.current() == "+" or self.current() == "-":
                    value += self.advance()
            else:
                break

        if is_float:
            return Token(TokenKind.FLOAT(), value, start_pos)
        else:
            return Token(TokenKind.INTEGER(), value, start_pos)

    def read_key(mut self) raises -> Token:
        """Read an unquoted key or boolean/datetime value.

        Unquoted keys can contain: a-z, A-Z, 0-9, _, -
        Examples: name, snake_case, kebab-case, CamelCase

        Also handles boolean keywords (true/false).

        Returns:
            KEY, BOOLEAN, or DATETIME token.
        """
        var start_pos = Position(self.line, self.column)
        var value = String("")

        while self.pos < len(self.chars):
            var c = self.current()
            if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or \
               (c >= "0" and c <= "9") or c == "_" or c == "-":
                value += self.advance()
            else:
                break

        # Check for boolean values
        if value == "true" or value == "false":
            return Token(TokenKind.BOOLEAN(), value, start_pos)

        # TODO: Detect datetime patterns (ISO 8601 with colons/dashes)
        # For now, treat as key and let parser handle datetime validation

        return Token(TokenKind.KEY(), value, start_pos)

    def next_token(mut self) raises -> Token:
        """Get the next token from the input.

        This is the main lexer logic that dispatches to specific readers
        based on the current character.

        Returns:
            Next token in the stream.
        """
        self.skip_whitespace()

        if self.pos >= len(self.chars):
            return Token(TokenKind.EOF(), "", Position(self.line, self.column))

        var c = self.current()
        var pos = Position(self.line, self.column)

        # Newline (significant in TOML)
        if c == "\n":
            _ = self.advance()
            return Token(TokenKind.NEWLINE(), "\n", pos)

        # Comment
        if c == "#":
            return self.read_comment()

        # Strings (basic or literal)
        if c == '"' or c == "'":
            return self.read_string()

        # Numbers and special floats (inf, nan)
        if (c >= "0" and c <= "9") or c == "+" or c == "-" or c == "i" or c == "n":
            # Check for special floats: inf, -inf, nan (must be standalone, not part of identifier)
            if c == "i" and self.peek(1) == "n" and self.peek(2) == "f":
                # Check if followed by non-identifier char (space, newline, EOF, etc.)
                var after = self.peek(3)
                if after == "" or after == " " or after == "\t" or after == "\n" or after == "#" or after == "," or after == "]" or after == "}":
                    return self.read_number()
            elif c == "n" and self.peek(1) == "a" and self.peek(2) == "n":
                # Check if followed by non-identifier char
                var after = self.peek(3)
                if after == "" or after == " " or after == "\t" or after == "\n" or after == "#" or after == "," or after == "]" or after == "}":
                    return self.read_number()
            elif c == "+" or c == "-":
                var next_c = self.peek(1)
                # Check for +inf, -inf, +nan, -nan
                if next_c >= "0" and next_c <= "9" or next_c == "i" or next_c == "n":
                    return self.read_number()
            elif c >= "0" and c <= "9":
                return self.read_number()

        # Single-character punctuation
        if c == "=":
            _ = self.advance()
            return Token(TokenKind.EQUALS(), "=", pos)
        if c == ".":
            _ = self.advance()
            return Token(TokenKind.DOT(), ".", pos)
        if c == ",":
            _ = self.advance()
            return Token(TokenKind.COMMA(), ",", pos)
        if c == "[":
            _ = self.advance()
            return Token(TokenKind.LEFT_BRACKET(), "[", pos)
        if c == "]":
            _ = self.advance()
            return Token(TokenKind.RIGHT_BRACKET(), "]", pos)
        if c == "{":
            _ = self.advance()
            return Token(TokenKind.LEFT_BRACE(), "{", pos)
        if c == "}":
            _ = self.advance()
            return Token(TokenKind.RIGHT_BRACE(), "}", pos)

        # Unquoted key or boolean
        return self.read_key()

    def is_hex_digit(self, c: String) -> Bool:
        """Check if character is a hexadecimal digit (0-9, a-f, A-F).

        Args:
            c: Character to check.

        Returns:
            True if c is a hex digit.
        """
        return (c >= "0" and c <= "9") or (c >= "a" and c <= "f") or (c >= "A" and c <= "F")

    def hex_to_int(self, hex_str: String) -> Int:
        """Convert a 2-character hex string to integer.

        Args:
            hex_str: Two hex digits (e.g. "1F", "a0").

        Returns:
            Integer value (0-255).
        """
        var result = 0
        # Avoid direct String indexing (0.26.1 changed __getitem__ semantics).
        # Convert to a list of single-character strings for stable indexing.
        var chars = List[String]()
        for slice in hex_str.codepoint_slices():
            chars.append(String(slice))
        for i in range(len(chars)):
            var c = chars[i]
            var digit_value: Int
            if c >= "0" and c <= "9":
                digit_value = ord(c) - ord("0")
            elif c >= "a" and c <= "f":
                digit_value = ord(c) - ord("a") + 10
            elif c >= "A" and c <= "F":
                digit_value = ord(c) - ord("A") + 10
            else:
                digit_value = 0
            result = result * 16 + digit_value
        return result

    def tokenize(mut self) raises -> List[Token]:
        """Tokenise entire input into list of tokens.

        This is the main public API for the lexer. It produces a complete
        list of tokens that can be consumed by the parser.

        Returns:
            List of all tokens in the input, ending with EOF.
        """
        var tokens = List[Token]()

        while True:
            var token = self.next_token()
            var is_eof = token.kind == TokenKind.EOF()
            tokens.append(token^)

            if is_eof:
                break

        return tokens^
