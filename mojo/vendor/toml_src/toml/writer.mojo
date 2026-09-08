"""Writer for TOML 1.0 files.

# Why: Purpose of the Writer
The writer is the serialisation component of mojo-toml. It converts structured
data (nested dictionaries and lists) back into valid TOML format strings.

Example transformation:
    Input: {"name": "mojo-toml", "port": 8080}
    Output: name = "mojo-toml"\nport = 8080\n

# What: Responsibilities
- Convert Dict[String, TomlValue] structures into TOML strings
- Handle all TOML value types (strings, numbers, bools, arrays, tables)
- Format strings with proper escaping
- Generate table headers for nested structures
- Produce human-readable, valid TOML output

# How: Writer Design
The writer uses a buffer-based approach:
1. Separate root keys from table keys
2. Write root key-value pairs first
3. Write tables with [section] headers
4. Format each value type appropriately
5. Return final TOML string

This keeps serialisation logic clean and predictable.
"""

from std.collections import Dict, List
from .parser import TomlValue, TomlValueType


struct Writer:
    """TOML writer for serialising Dict structures to TOML format.

    The writer builds TOML output incrementally in a string buffer,
    handling proper formatting, escaping, and structure.
    """

    var buffer: String

    def __init__(out self):
        """Initialise writer with empty buffer."""
        self.buffer = ""

    def escape_string(self, s: String) -> String:
        """Escape special characters in strings for TOML output.

        Handles:
        - Backslash: \\ -> \\\\
        - Quote: " -> \\"
        - Newline: \\n -> \\\\n
        - Tab: \\t -> \\\\t
        - Carriage return: \\r -> \\\\r
        - Escape char: ESC (U+001B) -> \\e (TOML 1.1)
        - Control chars: <32 -> \\xHH (TOML 1.1)
        Args:
            s: String to escape.
        Returns:
            Escaped string safe for TOML.
        """
        var result = String("")

        # Avoid direct String iteration under 0.26.1 by using codepoint_slices().
        for slice in s.codepoint_slices():
            var c = String(slice)
            var code = ord(c)

            if c == "\\":
                result += "\\\\"
            elif c == "\"":
                result += "\\\""
            elif c == "\n":
                result += "\\n"
            elif c == "\t":
                result += "\\t"
            elif c == "\r":
                result += "\\r"
            elif code == 0x1B:  # ESC character (TOML 1.1)
                result += "\\e"
            elif code < 32 or code == 127:  # Other control chars (TOML 1.1)
                # Use \xHH for control characters
                var hex_digits = List[String]()
                for slice in "0123456789abcdef".codepoint_slices():
                    hex_digits.append(String(slice))
                result += "\\x"
                result += hex_digits[code // 16]
                result += hex_digits[code % 16]
            else:
                result += c

        return result

    def format_string(self, s: String) -> String:
        """Format a string value for TOML output.

        Args:
            s: String value.
        Returns:
            Quoted and escaped string: "value"
        """
        return "\"" + self.escape_string(s) + "\""

    def format_integer(self, n: Int) -> String:
        """Format an integer value for TOML output.

        Args:
            n: Integer value.
        Returns:
            String representation: 42
        """
        return String(n)

    def format_float(self, f: Float64) -> String:
        """Format a float value for TOML output.

        Handles special values: inf, -inf, nan
        Args:
            f: Float value.
        Returns:
            String representation: 3.14, inf, nan
        """
        # Check for special values
        if f != f:  # NaN check (NaN != NaN)
            return "nan"

        # Check for infinity
        var pos_inf = Float64(1.0) / Float64(0.0)
        var neg_inf = Float64(-1.0) / Float64(0.0)

        if f == pos_inf:
            return "inf"
        elif f == neg_inf:
            return "-inf"
        else:
            return String(f)

    def format_boolean(self, b: Bool) -> String:
        """Format a boolean value for TOML output.

        Args:
            b: Boolean value.
        Returns:
            String representation: true or false
        """
        return "true" if b else "false"

    def format_array(self, arr: List[TomlValue]) raises -> String:
        """Format an array for TOML output.

        Args:
            arr: Array of TomlValue items.
        Returns:
            TOML array: [1, 2, 3]
        """
        var result = "["

        for i in range(len(arr)):
            if i > 0:
                result += ", "

            var item = arr[i].copy()
            result += self.format_value(item)

        result += "]"
        return result

    def format_inline_table(self, table: Dict[String, TomlValue]) raises -> String:
        """Format an inline table for TOML output.

        Args:
            table: Dictionary to format as inline table.
        Returns:
            TOML inline table: { key = "value", port = 8080 }
        """
        # Handle empty table
        if len(table) == 0:
            return "{ }"

        var result = "{ "
        var first = True

        for entry in table.items():
            if not first:
                result += ", "
            first = False

            result += entry.key + " = "
            result += self.format_value(entry.value)

        result += " }"
        return result

    def format_value(self, value: TomlValue) raises -> String:
        """Format any TomlValue for TOML output.

        Args:
            value: Value to format.
        Returns:
            Formatted TOML value.
        """
        if value.is_string():
            return self.format_string(value.as_string())
        elif value.is_int():
            return self.format_integer(value.as_int())
        elif value.is_float():
            return self.format_float(value.as_float())
        elif value.is_bool():
            return self.format_boolean(value.as_bool())
        elif value.is_array():
            return self.format_array(value.as_array())
        elif value.is_table():
            return self.format_inline_table(value.as_table())
        else:
            raise Error("Unknown value type")

    def should_use_inline(self, table: Dict[String, TomlValue]) -> Bool:
        """Determine if a table should be written as inline table.

        Heuristic:
        - 0-1 keys with only simple values (no nested tables): inline
        - 2+ keys or contains nested tables: regular table with [section]

        This conservative approach ensures root-level sections stay as sections,
        which maintains better TOML readability and round-trip fidelity.

        Args:
            table: Dictionary to evaluate.
        Returns:
            True if should use inline format, False for [section] format.
        """
        var num_keys = len(table)

        # Empty or single-key tables can be inline
        if num_keys > 1:
            return False

        # Check if any values are tables (nested structures)
        for entry in table.items():
            if entry.value.is_table():
                return False

        # Very small table (0-1 keys) with only simple values: use inline
        return True

    def write_key_value(mut self, key: String, value: TomlValue) raises:
        """Write a key-value pair to the buffer.

        Args:
            key: Key name.
            value: Value to write.
        """
        self.buffer += key + " = "
        self.buffer += self.format_value(value)
        self.buffer += "\n"

    def write_table_header(mut self, path: List[String]):
        """Write a table header to the buffer.

        Args:
            path: List of keys forming the table path.

        Example:
            path = ["database", "primary"] -> [database.primary]
        """
        self.buffer += "["

        for i in range(len(path)):
            if i > 0:
                self.buffer += "."
            self.buffer += path[i]

        self.buffer += "]\n"

    def write_table(mut self, path: List[String], table: Dict[String, TomlValue]) raises:
        """Write a table with proper [section] header.

        Recursively handles nested tables.

        Args:
            path: Current path to this table (e.g., ["database", "primary"]).
            table: Dictionary to write.
        """
        # Separate simple values, inline tables, and section tables
        var simple_keys = List[String]()
        var inline_table_keys = List[String]()
        var section_table_keys = List[String]()

        for entry in table.items():
            if entry.value.is_table():
                # All nested tables in write_table() always use section headers
                # This maintains proper TOML hierarchy
                section_table_keys.append(entry.key)
            else:
                simple_keys.append(entry.key)

        # Write table header if there are simple values or inline tables
        # (Don't write header for tables that contain ONLY nested section tables)
        if len(simple_keys) > 0 or len(inline_table_keys) > 0:
            self.write_table_header(path)

            # Write simple key-value pairs
            for i in range(len(simple_keys)):
                var key = simple_keys[i]
                self.write_key_value(key, table[key])

            # Write inline tables
            for i in range(len(inline_table_keys)):
                var key = inline_table_keys[i]
                self.write_key_value(key, table[key])
        elif len(section_table_keys) == 0:
            # Empty table with no content at all - write empty header
            self.write_table_header(path)

        # Write nested section tables
        for i in range(len(section_table_keys)):
            var key = section_table_keys[i]

            # Add blank line before nested table
            if len(simple_keys) > 0 or len(inline_table_keys) > 0 or i > 0:
                self.buffer += "\n"

            # Build new path
            var new_path = List[String]()
            for j in range(len(path)):
                new_path.append(path[j])
            new_path.append(key)

            # Recursively write nested table
            self.write_table(new_path, table[key].as_table())

    def to_string(self) -> String:
        """Get the final TOML string.

        Returns:
            Complete TOML document.
        """
        return self.buffer
def to_toml(config: Dict[String, TomlValue]) raises -> String:
    """Convert a Dict[String, TomlValue] structure to TOML format string.

    This is the main public API for TOML serialisation. It takes a nested
    dictionary structure and produces a valid TOML document.

    Args:
        config: Configuration dictionary to serialise.
    Returns:
        TOML format string.

    Example:
        ```mojo
        var config = Dict[String, TomlValue]()
        config["name"] = TomlValue("mojo-toml")
        config["port"] = TomlValue(8080)
        config["debug"] = TomlValue(False)

        var toml_str = to_toml(config)
        # Output:
        # name = "mojo-toml"
        # port = 8080
        # debug = false
        ```
    """
    var writer = Writer()

    # Separate root keys (non-tables) from table keys
    var root_keys = List[String]()
    var table_keys = List[String]()

    for entry in config.items():
        if entry.value.is_table():
            table_keys.append(entry.key)
        else:
            root_keys.append(entry.key)

    # Write root keys first
    for i in range(len(root_keys)):
        var key = root_keys[i]
        writer.write_key_value(key, config[key])

    # Write tables with proper [section] headers
    for i in range(len(table_keys)):
        var key = table_keys[i]
        var table = config[key].as_table()

        # Add blank line before first table if there were root keys
        if i == 0 and len(root_keys) > 0:
            writer.buffer += "\n"

        # Check if should use inline format
        if writer.should_use_inline(table):
            # Small simple table: write as inline
            writer.write_key_value(key, config[key])
        else:
            # Large or nested table: write with [section] header
            var path = List[String]()
            path.append(key)
            writer.write_table(path, table)

    return writer.to_string()
