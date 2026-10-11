package ion

/**
 * How [encode] writes one document.
 *
 * [version] is 10 for Ion 1.0 or 11 for Ion 1.1. [binary] selects the binary
 * encoding. [pretty] inserts newlines and indentation in text. Imports are
 * shared symbol tables the Ion 1.0 binary writer pulls in before local symbols.
 */
class EncodeOptions(
    var binary: Boolean = false,
    var pretty: Boolean = false,
    var version: Int = 10,
) {
    val importNames = ArrayList<String>()
    val importVersions = ArrayList<Int>()

    fun addImport(name: String, version: Int) {
        importNames.add(name)
        importVersions.add(version)
    }
}
