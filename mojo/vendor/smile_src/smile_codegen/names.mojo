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
        or name == "Self"
    ):
        return name + "_"
    return name


def struct_name(name: String) -> String:
    var raw = name.as_bytes()
    if len(raw) == 0:
        return String("Value")
    var out = String()
    var i = 0
    var cap = True
    while i < len(raw):
        var c = Int(raw[i])
        var ok = (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
        if (not cap) and c >= 48 and c <= 57:
            ok = True
        if ok:
            if cap and c >= 97 and c <= 122:
                c -= 32
            out = out + chr(c)
            cap = False
        else:
            cap = True
        i += 1
    if out.byte_length() == 0:
        return String("Value")
    var b = out.as_bytes()
    if Int(b[0]) >= 48 and Int(b[0]) <= 57:
        out = "T" + out
    return mojo_ident(out)


def field_name(name: String) -> String:
    var raw = name.as_bytes()
    var out = String()
    var i = 0
    while i < len(raw):
        var c = Int(raw[i])
        var ok = (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
        if i > 0 and c >= 48 and c <= 57:
            ok = True
        if ok:
            out = out + chr(c)
        else:
            out = out + "_"
        i += 1
    if out.byte_length() == 0:
        return String("field")
    var b = out.as_bytes()
    if Int(b[0]) >= 48 and Int(b[0]) <= 57:
        out = "f_" + out
    return mojo_ident(out)
