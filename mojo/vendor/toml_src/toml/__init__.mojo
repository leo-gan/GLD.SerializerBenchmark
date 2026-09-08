"""mojo-toml: The first native TOML 1.0 parser and writer for Mojo.

This module provides TOML parsing and writing capabilities without Python dependencies.

Example:
    from toml import parse, to_toml

    # Parse TOML
    var config = parse('''
        [package]
        name = "mojo-toml"
        version = "0.1.0"
    ''')

    # Write TOML
    var toml_str = to_toml(config)
"""

from .lexer import Lexer, Token, TokenKind, Position
from .parser import Parser, TomlValue, parse
from .writer import to_toml
