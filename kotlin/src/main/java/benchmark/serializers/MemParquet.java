package benchmark.serializers;

import org.apache.parquet.io.InputFile;
import org.apache.parquet.io.OutputFile;
import org.apache.parquet.io.PositionOutputStream;
import org.apache.parquet.io.SeekableInputStream;

import java.io.ByteArrayOutputStream;
import java.io.EOFException;
import java.io.IOException;
import java.nio.ByteBuffer;

/** In-memory Parquet {@link OutputFile} / {@link InputFile}. The writer never seeks. */
final class MemOutputFile implements OutputFile {
  private final ByteArrayOutputStream bos = new ByteArrayOutputStream();

  byte[] toByteArray() {
    return bos.toByteArray();
  }

  @Override
  public PositionOutputStream create(long blockSizeHint) {
    return stream();
  }

  @Override
  public PositionOutputStream createOrOverwrite(long blockSizeHint) {
    bos.reset();
    return stream();
  }

  @Override
  public boolean supportsBlockSize() {
    return false;
  }

  @Override
  public long defaultBlockSize() {
    return 0L;
  }

  private PositionOutputStream stream() {
    return new PositionOutputStream() {
      private long pos;

      @Override
      public long getPos() {
        return pos;
      }

      @Override
      public void write(int b) {
        bos.write(b);
        pos++;
      }

      @Override
      public void write(byte[] b, int off, int len) {
        bos.write(b, off, len);
        pos += len;
      }
    };
  }
}

final class MemInputFile implements InputFile {
  private final byte[] data;

  MemInputFile(byte[] data) {
    this.data = data;
  }

  @Override
  public long getLength() {
    return data.length;
  }

  @Override
  public SeekableInputStream newStream() {
    return new SeekableInputStream() {
      private int pos;

      @Override
      public long getPos() {
        return pos;
      }

      @Override
      public void seek(long newPos) {
        pos = (int) newPos;
      }

      @Override
      public int read() {
        if (pos >= data.length) return -1;
        return data[pos++] & 0xff;
      }

      @Override
      public int read(byte[] b, int off, int len) {
        if (pos >= data.length) return -1;
        int n = Math.min(len, data.length - pos);
        System.arraycopy(data, pos, b, off, n);
        pos += n;
        return n;
      }

      @Override
      public int read(ByteBuffer buf) {
        int n = Math.min(buf.remaining(), data.length - pos);
        if (n <= 0) return -1;
        buf.put(data, pos, n);
        pos += n;
        return n;
      }

      @Override
      public void readFully(byte[] b) throws IOException {
        readFully(b, 0, b.length);
      }

      @Override
      public void readFully(byte[] b, int off, int len) throws IOException {
        int got = 0;
        while (got < len) {
          int n = read(b, off + got, len - got);
          if (n < 0) throw new EOFException();
          got += n;
        }
      }

      @Override
      public void readFully(ByteBuffer buf) throws IOException {
        while (buf.hasRemaining()) {
          int n = read(buf);
          if (n < 0) throw new EOFException();
        }
      }
    };
  }
}
