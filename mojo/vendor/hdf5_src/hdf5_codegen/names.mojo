def sanitize(name: String) -> String:
    var raw = name.as_bytes()
    var out = String()
    if len(raw) == 0:
        return String("Value")
    var i = 0
    var c0 = Int(raw[0])
    if c0 >= 48 and c0 <= 57:
        out = String("_")
    while i < len(raw):
        var c = Int(raw[i])
        var ok = (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
        if ok:
            out = out + chr(c)
        else:
            out = out + String("_")
        i += 1
    return out
