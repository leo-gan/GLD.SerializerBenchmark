package benchmark.model.v2;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;

public final class Telemetry implements Serializable {
  private static final long serialVersionUID = 1L;

  public String source;
  public long ts;
  public List<String> tags = new ArrayList<>();
  public double[] values = new double[0];

  public Telemetry() {}

  public Telemetry(String source, long ts, List<String> tags, double[] values) {
    this.source = source;
    this.ts = ts;
    this.tags = tags != null ? tags : new ArrayList<>();
    this.values = values != null ? values : new double[0];
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Telemetry t)) return false;
    if (ts != t.ts || !Objects.equals(source, t.source) || !Objects.equals(tags, t.tags)) {
      return false;
    }
    if (values.length != t.values.length) return false;
    for (int i = 0; i < values.length; i++) {
      if (Math.abs(values[i] - t.values[i]) > 1e-9) return false;
    }
    return true;
  }

  @Override
  public int hashCode() {
    int result = Objects.hash(source, ts, tags);
    result = 31 * result + Arrays.hashCode(values);
    return result;
  }
}
