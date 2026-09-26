from std.collections import List


def is_name_start(c: Int) -> Bool:
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95


def is_name_part(c: Int) -> Bool:
    return is_name_start(c) or (c >= 48 and c <= 57)


def valid_unqualified_name(s: String) -> Bool:
    if s.byte_length() == 0:
        return False
    var b = s.as_bytes()
    if not is_name_start(Int(b[0])):
        return False
    var i = 1
    while i < len(b):
        if not is_name_part(Int(b[i])):
            return False
        i += 1
    return True


def unqualified_name(full: String) -> String:
    var b = full.as_bytes()
    var last = 0
    var i = 0
    while i < len(b):
        if Int(b[i]) == 46:
            last = i + 1
        i += 1
    if last == 0:
        return full
    var out = List[Byte]()
    while last < len(b):
        out.append(b[last])
        last += 1
    try:
        return String(from_utf8=out)
    except _:
        return full


def fullname_of(name: String, ns: String) -> String:
    var b = name.as_bytes()
    var i = 0
    while i < len(b):
        if Int(b[i]) == 46:
            return name
        i += 1
    if ns.byte_length() == 0:
        return name
    return ns + "." + name


def namespace_of(full: String) -> String:
    var b = full.as_bytes()
    var last = -1
    var i = 0
    while i < len(b):
        if Int(b[i]) == 46:
            last = i
        i += 1
    if last < 0:
        return String()
    var out = List[Byte]()
    var j = 0
    while j < last:
        out.append(b[j])
        j += 1
    try:
        return String(from_utf8=out)
    except _:
        return String()
