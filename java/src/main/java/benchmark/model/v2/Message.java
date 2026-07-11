package benchmark.model.v2;

import java.io.Serializable;
import java.util.Objects;

/** Single-level mixed-primitive record (type_id=message). */
public final class Message implements Serializable {
  private static final long serialVersionUID = 1L;

  public boolean fBool;
  public int fInt32;
  public long fInt64;
  public double fFloat64;
  public String fString;
  public boolean fBool2;
  public int fInt32_2;
  public String fString2;

  public Message() {}

  public Message(
      boolean fBool,
      int fInt32,
      long fInt64,
      double fFloat64,
      String fString,
      boolean fBool2,
      int fInt32_2,
      String fString2) {
    this.fBool = fBool;
    this.fInt32 = fInt32;
    this.fInt64 = fInt64;
    this.fFloat64 = fFloat64;
    this.fString = fString;
    this.fBool2 = fBool2;
    this.fInt32_2 = fInt32_2;
    this.fString2 = fString2;
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Message m)) return false;
    return fBool == m.fBool
        && fInt32 == m.fInt32
        && fInt64 == m.fInt64
        && Math.abs(m.fFloat64 - fFloat64) <= 1e-9
        && fBool2 == m.fBool2
        && fInt32_2 == m.fInt32_2
        && Objects.equals(fString, m.fString)
        && Objects.equals(fString2, m.fString2);
  }

  @Override
  public int hashCode() {
    return Objects.hash(fBool, fInt32, fInt64, fFloat64, fString, fBool2, fInt32_2, fString2);
  }
}
