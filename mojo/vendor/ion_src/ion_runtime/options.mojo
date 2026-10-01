from std.collections import List


struct EncodeOptions:
    """How `encode` writes one document.

    `version` is 10 for Ion 1.0 or 11 for Ion 1.1. `binary` selects the binary
    encoding. `pretty` inserts newlines and indentation in text. `import_names`
    and `import_versions` are shared symbol tables the binary writer imports,
    in order, before local symbols.
    """

    var binary: Bool
    var pretty: Bool
    var version: Int
    var import_names: List[String]
    var import_versions: List[Int]

    def __init__(out self, binary: Bool = False, pretty: Bool = False, version: Int = 10):
        self.binary = binary
        self.pretty = pretty
        self.version = version
        self.import_names = List[String]()
        self.import_versions = List[Int]()

    def add_import(mut self, name: String, version: Int):
        self.import_names.append(name)
        self.import_versions.append(version)
