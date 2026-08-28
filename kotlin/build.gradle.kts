import com.google.protobuf.gradle.id
import com.google.protobuf.gradle.proto

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
val jackson = "2.18.3"
val protobuf = "4.28.3"
val avro = "1.12.0"
val moshi = "1.15.2"
val kryo = "5.6.2"
val fory = "1.3.0"
val protostuff = "1.8.0"
val gson = "2.12.1"
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
    implementation("org.mongodb:bson:5.3.1")
    implementation("net.orandja.obor:obor:$obor")
    implementation("net.peanuuutz.tomlkt:tomlkt:$tomlkt")
    implementation("com.amazon.ion:ion-java:$ionJava")
    implementation("org.apache.thrift:libthrift:$thrift")
    implementation("org.slf4j:slf4j-nop:2.0.13")

    testImplementation("org.junit.jupiter:junit-jupiter:$junit")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

sourceSets {
    named("main") {
        proto {
            srcDir("${rootDir}/../schemas/v2/protobuf")
        }
    }
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
    )
}

tasks.shadowJar {
    archiveBaseName.set("serializer-benchmark-kotlin")
    archiveClassifier.set("")
    archiveVersion.set("1.0.0-SNAPSHOT")
    mergeServiceFiles()
    manifest {
        attributes["Main-Class"] = "benchmark.MainKt"
    }
    isZip64 = true
}

tasks.named("build") {
    dependsOn(tasks.shadowJar)
}
