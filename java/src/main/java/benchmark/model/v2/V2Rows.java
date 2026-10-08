package benchmark.model.v2;

import java.util.ArrayList;
import java.util.List;

/** Shared row-list and table_project helpers. */
public final class V2Rows {
  private V2Rows() {}

  public static List<TableRow> tables(Object value) {
    if (value instanceof TableRow row) return List.of(row);
    List<?> list = (List<?>) value;
    List<TableRow> out = new ArrayList<>(list.size());
    for (Object o : list) out.add((TableRow) o);
    return out;
  }

  public static List<NestedRow> nested(Object value) {
    if (value instanceof NestedRow row) return List.of(row);
    List<?> list = (List<?>) value;
    List<NestedRow> out = new ArrayList<>(list.size());
    for (Object o : list) out.add((NestedRow) o);
    return out;
  }

  public static List<Signal> signals(Object value) {
    if (value instanceof Signal row) return List.of(row);
    List<?> list = (List<?>) value;
    List<Signal> out = new ArrayList<>(list.size());
    for (Object o : list) out.add((Signal) o);
    return out;
  }

  /** f_float_0 column. N=1 is a one-element list, not a scalar. */
  public static List<Double> float0(Object decoded) {
    if (decoded instanceof TableRow row) {
      return List.of(Double.valueOf(row.fFloat0));
    }
    if (decoded instanceof List<?> list) {
      List<Double> out = new ArrayList<>(list.size());
      for (Object o : list) {
        if (o instanceof TableRow row) out.add(row.fFloat0);
        else if (o instanceof Number n) out.add(n.doubleValue());
        else throw new IllegalStateException("cannot project " + o.getClass().getName());
      }
      return out;
    }
    throw new IllegalStateException("cannot project " + decoded.getClass().getName());
  }

  public static Object oneOrList(List<?> rows, boolean batch) {
    if (!batch) {
      if (rows.isEmpty()) throw new IllegalStateException("empty batch");
      return rows.get(0);
    }
    return rows;
  }
}
