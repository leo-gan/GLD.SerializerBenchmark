package benchmark.serializers

import benchmark.model.Fixture
import com.amazon.ion.IonReader
import com.amazon.ion.IonSystem
import com.amazon.ion.IonType
import com.amazon.ion.IonWriter
import com.amazon.ion.system.IonSystemBuilder
import kotlinx.serialization.BinaryFormat
import kotlinx.serialization.DeserializationStrategy
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationStrategy
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.StructureKind
import kotlinx.serialization.encoding.AbstractDecoder
import kotlinx.serialization.encoding.AbstractEncoder
import kotlinx.serialization.encoding.CompositeDecoder
import kotlinx.serialization.modules.EmptySerializersModule
import kotlinx.serialization.modules.SerializersModule
import java.io.ByteArrayOutputStream

/**
 * Amazon Ion binary via kotlinx.serialization + official ion-java writer/reader.
 *
 * The community `kotlinx-serialization-ion` artifact is JitPack-only and unmaintained;
 * this uses the same kotlinx encoder/decoder contract on top of `com.amazon.ion:ion-java`.
 */
@OptIn(ExperimentalSerializationApi::class)
class KotlinxIonSer : BenchSerializer {
    private val format = IonFormat()
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "kotlinx-ion"

    override fun version() = Versions.of("com.amazon.ion.IonSystem")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray = format.encodeToByteArray(serializer, fx.value)

    override fun deserializeBytes(data: ByteArray): Any = format.decodeFromByteArray(serializer, data)
}

@OptIn(ExperimentalSerializationApi::class)
private class IonFormat : BinaryFormat {
    override val serializersModule: SerializersModule = EmptySerializersModule()
    private val system: IonSystem = IonSystemBuilder.standard().build()

    override fun <T> encodeToByteArray(serializer: SerializationStrategy<T>, value: T): ByteArray {
        val baos = ByteArrayOutputStream(256)
        system.newBinaryWriter(baos).use { writer ->
            IonEncoder(writer, serializersModule).encodeSerializableValue(serializer, value)
        }
        return baos.toByteArray()
    }

    override fun <T> decodeFromByteArray(deserializer: DeserializationStrategy<T>, bytes: ByteArray): T {
        system.newReader(bytes).use { reader ->
            reader.next()
            return IonDecoder(reader, serializersModule).decodeSerializableValue(deserializer)
        }
    }
}

@OptIn(ExperimentalSerializationApi::class)
private class IonEncoder(
    private val writer: IonWriter,
    override val serializersModule: SerializersModule,
) : AbstractEncoder() {
    private var pendingField: String? = null

    private fun applyField() {
        val name = pendingField
        if (name != null) {
            writer.setFieldName(name)
            pendingField = null
        }
    }

    override fun encodeElement(descriptor: SerialDescriptor, index: Int): Boolean {
        if (descriptor.kind is StructureKind.CLASS || descriptor.kind is StructureKind.OBJECT) {
            pendingField = descriptor.getElementName(index)
        }
        return true
    }

    override fun beginStructure(descriptor: SerialDescriptor): kotlinx.serialization.encoding.CompositeEncoder {
        applyField()
        when (descriptor.kind) {
            StructureKind.LIST, StructureKind.MAP -> writer.stepIn(IonType.LIST)
            else -> writer.stepIn(IonType.STRUCT)
        }
        return IonEncoder(writer, serializersModule)
    }

    override fun endStructure(descriptor: SerialDescriptor) {
        writer.stepOut()
    }

    override fun encodeBoolean(value: Boolean) {
        applyField()
        writer.writeBool(value)
    }

    override fun encodeByte(value: Byte) {
        applyField()
        writer.writeInt(value.toLong())
    }

    override fun encodeShort(value: Short) {
        applyField()
        writer.writeInt(value.toLong())
    }

    override fun encodeInt(value: Int) {
        applyField()
        writer.writeInt(value.toLong())
    }

    override fun encodeLong(value: Long) {
        applyField()
        writer.writeInt(value)
    }

    override fun encodeFloat(value: Float) {
        applyField()
        writer.writeFloat(value.toDouble())
    }

    override fun encodeDouble(value: Double) {
        applyField()
        writer.writeFloat(value)
    }

    override fun encodeString(value: String) {
        applyField()
        writer.writeString(value)
    }

    override fun encodeNull() {
        applyField()
        writer.writeNull()
    }

    override fun encodeEnum(enumDescriptor: SerialDescriptor, index: Int) {
        applyField()
        writer.writeString(enumDescriptor.getElementName(index))
    }
}

@OptIn(ExperimentalSerializationApi::class)
private class IonDecoder(
    private val reader: IonReader,
    override val serializersModule: SerializersModule,
    private val inCollection: Boolean = false,
) : AbstractDecoder() {
    private var index = 0

    override fun decodeElementIndex(descriptor: SerialDescriptor): Int {
        if (descriptor.kind is StructureKind.LIST || descriptor.kind is StructureKind.MAP) {
            val t = reader.next()
            if (t == null) return CompositeDecoder.DECODE_DONE
            return index++
        }
        val t = reader.next() ?: return CompositeDecoder.DECODE_DONE
        val name = reader.fieldName ?: return CompositeDecoder.DECODE_DONE
        val idx = descriptor.getElementIndex(name)
        return if (idx == CompositeDecoder.UNKNOWN_NAME) decodeElementIndex(descriptor) else idx
    }

    override fun beginStructure(descriptor: SerialDescriptor): CompositeDecoder {
        reader.stepIn()
        val list = descriptor.kind is StructureKind.LIST || descriptor.kind is StructureKind.MAP
        return IonDecoder(reader, serializersModule, list)
    }

    override fun endStructure(descriptor: SerialDescriptor) {
        reader.stepOut()
    }

    override fun decodeCollectionSize(descriptor: SerialDescriptor): Int = -1

    override fun decodeBoolean(): Boolean = reader.booleanValue()

    override fun decodeByte(): Byte = reader.intValue().toByte()

    override fun decodeShort(): Short = reader.intValue().toShort()

    override fun decodeInt(): Int = reader.intValue()

    override fun decodeLong(): Long = reader.longValue()

    override fun decodeFloat(): Float = reader.doubleValue().toFloat()

    override fun decodeDouble(): Double = reader.doubleValue()

    override fun decodeString(): String = reader.stringValue()

    override fun decodeEnum(enumDescriptor: SerialDescriptor): Int =
        enumDescriptor.getElementIndex(reader.stringValue())

    override fun decodeNotNullMark(): Boolean = reader.type != IonType.NULL

    override fun decodeNull(): Nothing? {
        return null
    }
}
