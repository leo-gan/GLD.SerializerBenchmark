package benchmark.model.v2;

import java.io.Serializable;
import java.util.Objects;

/** Wide flat row (type_id=table and table_project). Field order matches the catalog. */
public final class TableRow implements Serializable {
  private static final long serialVersionUID = 1L;

  public double fFloat0;
  public double fFloat1;
  public double fFloat2;
  public double fFloat3;
  public double fFloat4;
  public double fFloat5;
  public double fFloat6;
  public double fFloat7;
  public double fFloat8;
  public double fFloat9;
  public double fFloat10;
  public double fFloat11;
  public double fFloat12;
  public double fFloat13;
  public double fFloat14;
  public double fFloat15;
  public long fInt0;
  public long fInt1;
  public long fInt2;
  public long fInt3;
  public String fStr0;
  public String fStr1;

  public TableRow() {}

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof TableRow t)) return false;
    return close(fFloat0, t.fFloat0)
        && close(fFloat1, t.fFloat1)
        && close(fFloat2, t.fFloat2)
        && close(fFloat3, t.fFloat3)
        && close(fFloat4, t.fFloat4)
        && close(fFloat5, t.fFloat5)
        && close(fFloat6, t.fFloat6)
        && close(fFloat7, t.fFloat7)
        && close(fFloat8, t.fFloat8)
        && close(fFloat9, t.fFloat9)
        && close(fFloat10, t.fFloat10)
        && close(fFloat11, t.fFloat11)
        && close(fFloat12, t.fFloat12)
        && close(fFloat13, t.fFloat13)
        && close(fFloat14, t.fFloat14)
        && close(fFloat15, t.fFloat15)
        && fInt0 == t.fInt0
        && fInt1 == t.fInt1
        && fInt2 == t.fInt2
        && fInt3 == t.fInt3
        && Objects.equals(fStr0, t.fStr0)
        && Objects.equals(fStr1, t.fStr1);
  }

  private static boolean close(double a, double b) {
    return Math.abs(a - b) <= 1e-9;
  }

  @Override
  public int hashCode() {
    return Objects.hash(
        fFloat0, fFloat1, fFloat2, fFloat3, fFloat4, fFloat5, fFloat6, fFloat7, fFloat8, fFloat9,
        fFloat10, fFloat11, fFloat12, fFloat13, fFloat14, fFloat15, fInt0, fInt1, fInt2, fInt3,
        fStr0, fStr1);
  }
}
