package benchmark.serializers;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.ByteBufferReadable;
import org.apache.hadoop.fs.FSDataInputStream;
import org.apache.hadoop.fs.FSDataOutputStream;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.PositionedReadable;
import org.apache.hadoop.fs.Seekable;
import org.apache.hadoop.fs.Syncable;
import org.apache.hadoop.fs.permission.FsPermission;
import org.apache.hadoop.util.Progressable;

import java.io.ByteArrayOutputStream;
import java.io.EOFException;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

/**
 * Process-local file system for ORC's Path API.
 * ORC's writer appends and {@code hflush}es; it does not seek the output.
 */
final class MemoryOrcFileSystem extends FileSystem {
  private final Map<String, byte[]> files = new HashMap<>();
  private final Map<String, Accumulator> open = new HashMap<>();
  private Path working = new Path("mem:///");
  private int seq;

  MemoryOrcFileSystem(Configuration conf) throws IOException {
    // Hadoop 3.4 FileSystem.initialize does not store the Configuration.
    // FileSystem.open(Path) reads it via getConf().
    setConf(conf);
    initialize(URI.create("mem:///"), conf);
  }

  Path putBytes(byte[] data) {
    String key = "/r-" + (++seq) + ".orc";
    files.put(key, data);
    return new Path("mem://" + key);
  }

  byte[] take(Path path) throws IOException {
    String key = key(path);
    byte[] data = files.remove(key);
    if (data == null) {
      throw new FileNotFoundException(path + " keys=" + files.keySet() + " open=" + open.keySet());
    }
    return data;
  }

  @Override
  public String getScheme() {
    return "mem";
  }

  @Override
  public URI getUri() {
    return URI.create("mem:///");
  }

  @Override
  public FSDataInputStream open(Path f, int bufferSize) throws IOException {
    byte[] data = files.get(key(f));
    if (data == null) {
      throw new FileNotFoundException(f + " keys=" + files.keySet());
    }
    return new FSDataInputStream(new MemIn(data));
  }

  @Override
  public FSDataOutputStream create(
      Path f,
      FsPermission permission,
      boolean overwrite,
      int bufferSize,
      short replication,
      long blockSize,
      Progressable progress)
      throws IOException {
    String key = key(f);
    if (files.containsKey(key) || open.containsKey(key)) {
      if (!overwrite) {
        throw new IOException("exists: " + f);
      }
      files.remove(key);
      open.remove(key);
    }
    Accumulator acc = new Accumulator(key);
    open.put(key, acc);
    return new FSDataOutputStream(acc, statistics);
  }

  @Override
  public FSDataOutputStream append(Path f, int bufferSize, Progressable progress) {
    throw new UnsupportedOperationException("append");
  }

  @Override
  public boolean rename(Path src, Path dst) {
    String from = key(src);
    String to = key(dst);
    Accumulator acc = open.remove(from);
    if (acc != null) {
      acc.key = to;
      open.put(to, acc);
      return true;
    }
    byte[] data = files.remove(from);
    if (data == null) return false;
    files.put(to, data);
    return true;
  }

  @Override
  public boolean delete(Path f, boolean recursive) {
    String key = key(f);
    if ("/".equals(key) && recursive) {
      files.clear();
      open.clear();
      return true;
    }
    return files.remove(key) != null || open.remove(key) != null;
  }

  @Override
  public FileStatus[] listStatus(Path f) throws IOException {
    String key = key(f);
    if ("/".equals(key)) {
      FileStatus[] out = new FileStatus[files.size()];
      int i = 0;
      for (Map.Entry<String, byte[]> e : files.entrySet()) {
        out[i++] = status(e.getKey(), e.getValue().length, false);
      }
      return out;
    }
    return new FileStatus[] {getFileStatus(f)};
  }

  @Override
  public void setWorkingDirectory(Path newDir) {
    working = newDir;
  }

  @Override
  public Path getWorkingDirectory() {
    return working;
  }

  @Override
  public boolean mkdirs(Path f, FsPermission permission) {
    return true;
  }

  @Override
  public FileStatus getFileStatus(Path f) throws IOException {
    String key = key(f);
    if ("/".equals(key)) return status(key, 0, true);
    Accumulator acc = open.get(key);
    if (acc != null) return status(key, acc.bos.size(), false);
    byte[] data = files.get(key);
    if (data == null) throw new FileNotFoundException(f.toString());
    return status(key, data.length, false);
  }

  private FileStatus status(String key, long length, boolean dir) {
    return new FileStatus(length, dir, 1, 4096, 0L, new Path("mem://" + key));
  }

  static String key(Path path) {
    URI uri = path.toUri();
    String p = uri.getPath();
    if (p == null || p.isEmpty()) p = "/";
    if (!p.startsWith("/")) p = "/" + p;
    return p;
  }

  private final class Accumulator extends OutputStream implements Syncable {
    private final ByteArrayOutputStream bos = new ByteArrayOutputStream();
    private String key;
    private boolean closed;

    Accumulator(String key) {
      this.key = key;
    }

    @Override
    public void write(int b) {
      bos.write(b);
    }

    @Override
    public void write(byte[] b, int off, int len) {
      bos.write(b, off, len);
    }

    @Override
    public void hflush() {}

    @Override
    public void hsync() {}

    @Override
    public void close() {
      if (closed) return;
      closed = true;
      files.put(key, bos.toByteArray());
      open.remove(key);
    }
  }

  private static final class MemIn extends InputStream
      implements Seekable, PositionedReadable, ByteBufferReadable {
    private final byte[] data;
    private int pos;

    MemIn(byte[] data) {
      this.data = data;
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
    public void seek(long target) {
      pos = (int) target;
    }

    @Override
    public long getPos() {
      return pos;
    }

    @Override
    public boolean seekToNewSource(long targetPos) {
      return false;
    }

    @Override
    public int read(long position, byte[] buffer, int offset, int length) {
      if (position >= data.length) return -1;
      int n = (int) Math.min(length, data.length - position);
      System.arraycopy(data, (int) position, buffer, offset, n);
      return n;
    }

    @Override
    public void readFully(long position, byte[] buffer, int offset, int length) throws IOException {
      int got = 0;
      while (got < length) {
        int n = read(position + got, buffer, offset + got, length - got);
        if (n < 0) throw new EOFException();
        got += n;
      }
    }

    @Override
    public void readFully(long position, byte[] buffer) throws IOException {
      readFully(position, buffer, 0, buffer.length);
    }

    @Override
    public int read(ByteBuffer buf) throws IOException {
      int n = Math.min(buf.remaining(), Math.max(0, data.length - pos));
      if (n <= 0) return -1;
      buf.put(data, pos, n);
      pos += n;
      return n;
    }
  }
}
