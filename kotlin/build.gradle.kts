import com.google.protobuf.gradle.id
import com.google.protobuf.gradle.proto
import org.gradle.api.artifacts.ExternalModuleDependency

buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath("org.apache.avro:avro-compiler:1.12.1")
    }
}

plugins {
    kotlin("jvm") version "2.1.20"
    kotlin("plugin.serialization") version "2.1.20"
    id("com.google.devtools.ksp") version "2.1.20-1.0.31"
    id("com.google.protobuf") version "0.9.4"
    id("com.gradleup.shadow") version "8.3.6"
    application
    jacoco
}

group = "benchmark"
version = "1.0.0-SNAPSHOT"

val kotlinVersion = "2.1.20"
val kotlinxSerialization = "1.8.1"
val jackson = "2.19.0"
val protobuf = "4.35.0"
val avro = "1.12.1"
val moshi = "1.15.2"
val kryo = "5.6.2"
val fory = "1.3.0"
val protostuff = "1.8.0"
val gson = "2.14.0"
val avro4k = "2.9.0"
val kbson = "0.5.0"
val obor = "2.1.3"
val tomlkt = "0.5.0"
val ionJava = "1.11.11"
val thrift = "0.21.0"
val kaml = "0.72.0"
val msgpack = "0.9.8"
val flatbuffers = "24.3.25"
val capnproto = "0.1.16"
val arrow = "19.0.0"
val parquet = "1.18.1"
val orc = "2.3.1"
val orcFormat = "1.1.1"
val sbeToolVersion = "1.40.2"
val agrona = "2.6.1"
val junit = "5.11.4"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        optIn.add("kotlinx.serialization.ExperimentalSerializationApi")
    }
}

application {
    mainClass.set("benchmark.MainKt")
}

repositories {
    mavenCentral()
}

// Arrow 19 pulls flatbuffers-java 25.2.10. The checked-in tables call
// Constants.FLATBUFFERS_24_3_25(). Maven nearest-wins keeps 24.3.25; Gradle does not.
configurations.configureEach {
    resolutionStrategy {
        force("com.google.flatbuffers:flatbuffers-java:$flatbuffers")
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:$kotlinxSerialization")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-cbor:$kotlinxSerialization")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-protobuf:$kotlinxSerialization")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-properties:$kotlinxSerialization")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-hocon:$kotlinxSerialization")
    implementation("com.charleskorn.kaml:kaml:$kaml")

    implementation("com.fasterxml.jackson.core:jackson-databind:$jackson")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin:$jackson")
    implementation("com.fasterxml.jackson.dataformat:jackson-dataformat-cbor:$jackson")
    implementation("com.fasterxml.jackson.dataformat:jackson-dataformat-ion:$jackson")

    implementation("com.squareup.moshi:moshi:$moshi")
    implementation("com.squareup.moshi:moshi-kotlin:$moshi")
    ksp("com.squareup.moshi:moshi-kotlin-codegen:$moshi")

    implementation("com.google.code.gson:gson:$gson")

    implementation("com.esotericsoftware:kryo:$kryo")
    implementation("org.apache.fory:fory-core:$fory")
    implementation("io.protostuff:protostuff-core:$protostuff")
    implementation("io.protostuff:protostuff-runtime:$protostuff")

    implementation("com.google.protobuf:protobuf-java:$protobuf")
    implementation("com.google.protobuf:protobuf-java-util:$protobuf")
    implementation("com.google.protobuf:protobuf-kotlin:$protobuf")
    implementation("org.msgpack:jackson-dataformat-msgpack:$msgpack")
    implementation("com.google.flatbuffers:flatbuffers-java:$flatbuffers")
    implementation("org.capnproto:runtime:$capnproto")
    implementation("org.apache.avro:avro:$avro")
    implementation("com.github.avro-kotlin.avro4k:avro4k-core:$avro4k")

    implementation("com.github.jershell:kbson:$kbson") {
        exclude(group = "org.jetbrains.kotlinx")
        exclude(group = "org.jetbrains.kotlin")
    }
    implementation("org.mongodb:bson:5.5.1")
    implementation("net.orandja.obor:obor:$obor")
    implementation("net.peanuuutz.tomlkt:tomlkt:$tomlkt")
    implementation("com.amazon.ion:ion-java:$ionJava")
    implementation("org.apache.thrift:libthrift:$thrift")
    implementation("org.slf4j:slf4j-nop:2.0.13")

    implementation("org.apache.arrow:arrow-vector:$arrow")
    // arrow-vector marks the Netty allocator test-scoped; RootAllocator needs it at runtime.
    implementation("org.apache.arrow:arrow-memory-netty:$arrow")
    implementation("org.apache.parquet:parquet-avro:$parquet")
    // nohive relocates hive-storage-api vectors to org.apache.orc.storage and calls
    // org.apache.orc.protobuf. The default orc-format jar is compiled against
    // com.google.protobuf, so this build uses orc-format nohive.
    implementation("org.apache.orc:orc-core:$orc:nohive") {
        exclude(group = "org.apache.orc", module = "orc-format")
    }
    implementation("org.apache.orc:orc-format:$orcFormat:nohive")
    implementation("org.agrona:agrona:$agrona")

    testImplementation("org.junit.jupiter:junit-jupiter:$junit")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

val sbeAllDep =
    (dependencies.create("uk.co.real-logic:sbe-all:$sbeToolVersion") as ExternalModuleDependency).apply {
        isTransitive = false
    }
val sbeAllCfg = configurations.detachedConfiguration(sbeAllDep)

val copySbeAll =
    tasks.register<Copy>("copySbeAll") {
        from(sbeAllCfg)
        into(layout.buildDirectory.dir("sbe"))
        rename { "sbe-all-$sbeToolVersion.jar" }
    }

val generateSbe =
    tasks.register<Exec>("generateSbe") {
        dependsOn(copySbeAll)
        val schema = rootDir.resolve("../schemas/v2/sbe/signal.xml")
        val jar = layout.buildDirectory.file("sbe/sbe-all-$sbeToolVersion.jar")
        val outDir = layout.buildDirectory.dir("generated/sbe")
        inputs.file(schema)
        inputs.file(jar)
        outputs.dir(outDir)
        val javaBin =
            javaToolchains.launcherFor {
                languageVersion.set(JavaLanguageVersion.of(21))
            }.get().executablePath.asFile.absolutePath
        executable = javaBin
        doFirst { outDir.get().asFile.mkdirs() }
        args(
            "--add-opens",
            "java.base/jdk.internal.misc=ALL-UNNAMED",
            "-Dsbe.output.dir=${outDir.get().asFile.absolutePath}",
            "-Dsbe.target.language=Java",
            "-jar",
            jar.get().asFile.absolutePath,
            schema.absolutePath,
        )
    }

// Protobuf owns package benchmark.v2. Rewrite the copied avsc namespace before SpecificCompiler.
val generateAvro =
    tasks.register("generateAvro") {
        val schemaSrc = rootDir.resolve("../schemas/v2/avro")
        val schemaDir = layout.buildDirectory.dir("avro-schema")
        val outDir = layout.buildDirectory.dir("generated/avro")
        inputs.files(
            schemaSrc.resolve("table.avsc"),
            schemaSrc.resolve("nested_table.avsc"),
            schemaSrc.resolve("signal.avsc"),
        )
        outputs.dir(outDir)
        doLast {
            val dest = schemaDir.get().asFile
            dest.mkdirs()
            val names = listOf("table.avsc", "nested_table.avsc", "signal.avsc")
            val rewritten =
                names.map { name ->
                    val text =
                        schemaSrc.resolve(name).readText()
                            .replace("\"namespace\": \"benchmark.v2\"", "\"namespace\": \"benchmark.v2.avro\"")
                    val file = dest.resolve(name)
                    file.writeText(text)
                    file
                }
            val parser = org.apache.avro.Schema.Parser()
            val schemas = rewritten.map { parser.parse(it) }
            val compiler = org.apache.avro.compiler.specific.SpecificCompiler(schemas)
            compiler.setStringType(org.apache.avro.generic.GenericData.StringType.String)
            compiler.setFieldVisibility(
                org.apache.avro.compiler.specific.SpecificCompiler.FieldVisibility.PRIVATE,
            )
            val output = outDir.get().asFile
            output.mkdirs()
            compiler.compileToDestination(dest, output)
        }
    }

sourceSets {
    named("main") {
        java {
            srcDir(layout.buildDirectory.dir("generated/avro"))
            srcDir(layout.buildDirectory.dir("generated/sbe"))
        }
        proto {
            srcDir("${rootDir}/../schemas/v2/protobuf")
        }
    }
}

tasks.named("compileJava") {
    dependsOn(generateAvro, generateSbe)
}

tasks.named("compileKotlin") {
    dependsOn(generateAvro, generateSbe)
}

// KSP registers its task after the project is evaluated.
tasks.matching { it.name == "kspKotlin" }.configureEach {
    dependsOn(generateAvro, generateSbe)
}

protobuf {
    protoc {
        artifact = "com.google.protobuf:protoc:$protobuf"
    }
    generateProtoTasks {
        all().forEach { task ->
            task.builtins {
                id("kotlin")
            }
        }
    }
}

tasks.processResources {
    filesMatching("benchmark-versions.properties") {
        expand(
            mapOf(
                "kotlinxSerialization" to kotlinxSerialization,
                "jackson" to jackson,
                "protobuf" to protobuf,
                "avro" to avro,
                "moshi" to moshi,
                "kryo" to kryo,
                "fory" to fory,
                "protostuff" to protostuff,
                "gson" to gson,
                "avro4k" to avro4k,
                "kbson" to kbson,
                "obor" to obor,
                "tomlkt" to tomlkt,
                "ionJava" to ionJava,
                "thrift" to thrift,
                "kaml" to kaml,
                "msgpack" to msgpack,
                "flatbuffers" to flatbuffers,
                "capnproto" to capnproto,
                "arrow" to arrow,
                "parquet" to parquet,
                "orc" to orc,
            )
        )
    }
}

tasks.test {
    useJUnitPlatform()
    jvmArgs(
        "--add-opens", "java.base/java.lang=ALL-UNNAMED",
        "--add-opens", "java.base/java.util=ALL-UNNAMED",
        "--add-opens", "java.base/java.lang.reflect=ALL-UNNAMED",
        "--add-opens", "java.base/java.text=ALL-UNNAMED",
        "--add-opens", "java.base/java.io=ALL-UNNAMED",
        "--add-opens", "java.base/java.nio=ALL-UNNAMED",
        "--add-opens", "java.base/java.nio=org.apache.arrow.memory.core,ALL-UNNAMED",
        "--add-opens", "java.base/jdk.internal.misc=ALL-UNNAMED",
    )
    maxHeapSize = "2g"
    testLogging {
        showStandardStreams = true
    }
}

tasks.shadowJar {
    archiveBaseName.set("serializer-benchmark-kotlin")
    archiveClassifier.set("")
    archiveVersion.set("1.0.0-SNAPSHOT")
    mergeServiceFiles()
    exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")
    exclude("**/module-info.class")
    manifest {
        attributes["Main-Class"] = "benchmark.MainKt"
    }
    isZip64 = true
}

tasks.named("build") {
    dependsOn(tasks.shadowJar)
}
