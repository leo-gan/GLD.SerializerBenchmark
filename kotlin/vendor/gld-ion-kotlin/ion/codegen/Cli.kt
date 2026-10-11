package ion.codegen

import ion.schema.parseSchemaFile
import java.io.File

fun main(args: Array<String>) {
    var schemaPath = ""
    var outDir = ""
    var i = 0
    while (i < args.size) {
        when (args[i]) {
            "--schema" -> {
                if (i + 1 < args.size) schemaPath = args[++i]
            }
            "--out" -> {
                if (i + 1 < args.size) outDir = args[++i]
            }
            "--help", "-h" -> {
                println("gld-iongen-kotlin --schema FILE --out DIR")
                return
            }
        }
        i++
    }
    if (schemaPath.isEmpty() || outDir.isEmpty()) {
        println("gld-iongen-kotlin --schema FILE --out DIR")
        return
    }
    val schema = parseSchemaFile(schemaPath)
    val files = emitAll(schema)
    File(outDir).mkdirs()
    var k = 0
    while (k + 1 < files.size) {
        val path = File(outDir, files[k] + ".kt")
        path.writeText(files[k + 1])
        println("wrote " + path.path)
        k += 2
    }
}
