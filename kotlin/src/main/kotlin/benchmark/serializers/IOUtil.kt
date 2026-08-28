package benchmark.serializers

import java.io.OutputStream

/** Counts bytes written while forwarding to a delegate stream. */
class CountingOutputStream(private val delegate: OutputStream) : OutputStream() {
    var count: Int = 0
        private set

    override fun write(b: Int) {
        delegate.write(b)
        count++
    }

    override fun write(b: ByteArray, off: Int, len: Int) {
        delegate.write(b, off, len)
        count += len
    }
}
