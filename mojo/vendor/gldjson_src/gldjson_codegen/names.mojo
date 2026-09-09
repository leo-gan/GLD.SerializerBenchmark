def mojo_ident(name: String) -> String:
    if (
        name == "struct"
        or name == "fn"
        or name == "var"
        or name == "def"
        or name == "trait"
        or name == "alias"
        or name == "if"
        or name == "else"
        or name == "for"
        or name == "while"
        or name == "return"
        or name == "raise"
        or name == "from"
        or name == "import"
        or name == "as"
        or name == "match"
        or name == "True"
        or name == "False"
        or name == "None"
    ):
        return name + "_"
    return name
