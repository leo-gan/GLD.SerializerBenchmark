package benchmark.model.v2;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class Strings implements Serializable {
  private static final long serialVersionUID = 1L;

  public List<String> items = new ArrayList<>();

  public Strings() {}

  public Strings(List<String> items) {
    this.items = items != null ? items : new ArrayList<>();
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Strings s)) return false;
    return Objects.equals(items, s.items);
  }

  @Override
  public int hashCode() {
    return Objects.hash(items);
  }
}
