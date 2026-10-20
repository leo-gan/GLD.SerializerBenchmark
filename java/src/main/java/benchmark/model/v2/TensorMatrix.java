package benchmark.model.v2;

import java.io.Serializable;
import java.util.Objects;

/**
 * Row-major float32 matrix (type_id=tensor). Index 0 is negative zero and index 1 is quiet NaN
 * {@code 0x7fc00000}. Equality is raw float32 bits.
 *
 * <p>{@link View} is a decode borrow of the encoded payload. It does not own a second copy.
 */
public final class TensorMatrix implements Serializable {
  private static final long serialVersionUID = 1L;

  public int rows;
  public int cols;
  public float[] values = new float[0];

  public TensorMatrix() {}

  public TensorMatrix(int rows, int cols, float[] values) {
    this.rows = rows;
    this.cols = cols;
    this.values = values != null ? values : new float[0];
  }

  /** Encoded buffer slice. Payload is {@code data[offset .. offset+length)} little-endian f32. */
  public static final class View implements Serializable {
    private static final long serialVersionUID = 1L;

    public final int rows;
    public final int cols;
    public final byte[] data;
    public final int offset;
    public final int length;

    public View(int rows, int cols, byte[] data, int offset, int length) {
      this.rows = rows;
      this.cols = cols;
      this.data = data;
      this.offset = offset;
      this.length = length;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (o instanceof TensorMatrix m) return m.equals(this);
      if (!(o instanceof View v)) return false;
      return rows == v.rows
          && cols == v.cols
          && sameSlice(data, offset, length, v.data, v.offset, v.length);
    }

    @Override
    public int hashCode() {
      return payloadHash(rows, cols, data, offset, length);
    }
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (o instanceof TensorMatrix t) {
      return rows == t.rows && cols == t.cols && sameBits(values, t.values);
    }
    if (o instanceof View v) {
      return rows == v.rows && cols == v.cols && sameBits(values, v.data, v.offset, v.length);
    }
    return false;
  }

  @Override
  public int hashCode() {
    return payloadHash(rows, cols, values);
  }

  static boolean sameBits(float a, float b) {
    return Float.floatToRawIntBits(a) == Float.floatToRawIntBits(b);
  }

  static boolean sameBits(float[] a, float[] b) {
    if (a == b) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!sameBits(a[i], b[i])) return false;
    }
    return true;
  }

  static boolean sameBits(float[] values, byte[] data, int offset, int length) {
    if (values == null || data == null || offset < 0 || length < 0) return false;
    if ((long) values.length * 4L != length) return false;
    if ((long) offset + length > data.length) return false;
    for (int i = 0; i < values.length; i++) {
      if (Float.floatToRawIntBits(values[i]) != leI32(data, offset + i * 4)) return false;
    }
    return true;
  }

  private static boolean sameSlice(byte[] a, int aOff, int aLen, byte[] b, int bOff, int bLen) {
    if (aLen != bLen || a == null || b == null) return false;
    if (aOff < 0 || bOff < 0 || (long) aOff + aLen > a.length || (long) bOff + bLen > b.length) {
      return false;
    }
    for (int i = 0; i < aLen; i++) {
      if (a[aOff + i] != b[bOff + i]) return false;
    }
    return true;
  }

  private static int payloadHash(int rows, int cols, float[] values) {
    int h = 1;
    if (values != null) {
      for (float v : values) {
        h = 31 * h + Float.floatToIntBits(v);
      }
    }
    return 31 * Objects.hash(rows, cols) + h;
  }

  private static int payloadHash(int rows, int cols, byte[] data, int offset, int length) {
    int h = 1;
    if (data != null && offset >= 0 && length >= 0 && (long) offset + length <= data.length) {
      for (int i = 0; i + 4 <= length; i += 4) {
        int bits = leI32(data, offset + i);
        h = 31 * h + Float.floatToIntBits(Float.intBitsToFloat(bits));
      }
    }
    return 31 * Objects.hash(rows, cols) + h;
  }

  private static int leI32(byte[] data, int p) {
    return (data[p] & 0xFF)
        | ((data[p + 1] & 0xFF) << 8)
        | ((data[p + 2] & 0xFF) << 16)
        | (data[p + 3] << 24);
  }

  @Override
  public String toString() {
    return "TensorMatrix{rows=" + rows + ", cols=" + cols + ", n=" + values.length + "}";
  }
}
