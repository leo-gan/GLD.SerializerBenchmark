package benchmark.model.v2;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/** Struct plus a list of structs (type_id=nested_table). */
public final class NestedRow implements Serializable {
  private static final long serialVersionUID = 1L;

  public String id;
  public int status;
  public NestedMeta meta;
  public List<NestedItem> items = new ArrayList<>();

  public NestedRow() {}

  public NestedRow(String id, int status, NestedMeta meta, List<NestedItem> items) {
    this.id = id;
    this.status = status;
    this.meta = meta;
    this.items = items != null ? items : new ArrayList<>();
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof NestedRow n)) return false;
    return status == n.status
        && Objects.equals(id, n.id)
        && Objects.equals(meta, n.meta)
        && Objects.equals(items, n.items);
  }

  @Override
  public int hashCode() {
    return Objects.hash(id, status, meta, items);
  }

  public static final class NestedMeta implements Serializable {
    private static final long serialVersionUID = 1L;
    public String region;
    public int version;

    public NestedMeta() {}

    public NestedMeta(String region, int version) {
      this.region = region;
      this.version = version;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof NestedMeta m)) return false;
      return version == m.version && Objects.equals(region, m.region);
    }

    @Override
    public int hashCode() {
      return Objects.hash(region, version);
    }
  }

  public static final class NestedItem implements Serializable {
    private static final long serialVersionUID = 1L;
    public String sku;
    public int qty;
    public long priceMinor;

    public NestedItem() {}

    public NestedItem(String sku, int qty, long priceMinor) {
      this.sku = sku;
      this.qty = qty;
      this.priceMinor = priceMinor;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof NestedItem i)) return false;
      return qty == i.qty && priceMinor == i.priceMinor && Objects.equals(sku, i.sku);
    }

    @Override
    public int hashCode() {
      return Objects.hash(sku, qty, priceMinor);
    }
  }
}
