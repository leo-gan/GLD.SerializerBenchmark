from std.collections import List

from fb_schema.model import Schema


def last_part(name: String) raises -> String:
    var raw = name.as_bytes()
    var start = 0
    for i in range(len(raw)):
        if raw[i] == Byte(ord(".")):
            start = i + 1
    var buf = List[Byte]()
    for i in range(start, len(raw)):
        buf.append(raw[i])
    return String(from_utf8=Span(buf))


def mojo_ident(name: String) -> String:
    if (
        name == "type"
        or name == "struct"
        or name == "def"
        or name == "var"
        or name == "alias"
        or name == "fn"
        or name == "trait"
        or name == "self"
        or name == "Self"
        or name == "from"
        or name == "import"
        or name == "as"
        or name == "object"
        or name == "in"
        or name == "raise"
        or name == "True"
        or name == "False"
        or name == "None"
    ):
        return name + "_"
    return name


def type_names(schema: Schema) raises -> List[String]:
    """Short Mojo names for objects, disambiguated when the last component repeats."""
    var names = List[String]()
    for i in range(len(schema.objects)):
        names.append(mojo_ident(last_part(schema.objects[i].name)))
    for i in range(len(names)):
        var dup = False
        for j in range(len(names)):
            if i != j and names[i] == names[j]:
                dup = True
        if dup:
            names[i] = mojo_ident(schema.objects[i].name.replace(".", "_"))
    return names^


def enum_names(schema: Schema) raises -> List[String]:
    var names = List[String]()
    for i in range(len(schema.enums)):
        names.append(mojo_ident(last_part(schema.enums[i].name)))
    for i in range(len(names)):
        var dup = False
        for j in range(len(names)):
            if i != j and names[i] == names[j]:
                dup = True
        if dup:
            names[i] = mojo_ident(schema.enums[i].name.replace(".", "_"))
    return names^
