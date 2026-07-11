package benchmark.model.v2;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

public final class Document implements Serializable {
  private static final long serialVersionUID = 1L;

  public String id;
  public int status;
  public DocumentMeta meta;
  public List<DocumentItem> items = new ArrayList<>();

  public Document() {}

  public Document(String id, int status, DocumentMeta meta, List<DocumentItem> items) {
    this.id = id;
    this.status = status;
    this.meta = meta;
    this.items = items != null ? items : new ArrayList<>();
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Document d)) return false;
    return status == d.status
        && Objects.equals(id, d.id)
        && Objects.equals(meta, d.meta)
        && Objects.equals(items, d.items);
  }

  @Override
  public int hashCode() {
    return Objects.hash(id, status, meta, items);
  }

  public static final class DocumentMeta implements Serializable {
    private static final long serialVersionUID = 1L;
    public String region;
    public int version;

    public DocumentMeta() {}

    public DocumentMeta(String region, int version) {
      this.region = region;
      this.version = version;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof DocumentMeta m)) return false;
      return version == m.version && Objects.equals(region, m.region);
    }

    @Override
    public int hashCode() {
      return Objects.hash(region, version);
    }
  }

  public static final class DocumentItem implements Serializable {
    private static final long serialVersionUID = 1L;
    public String sku;
    public int qty;
    public long priceMinor;

    public DocumentItem() {}

    public DocumentItem(String sku, int qty, long priceMinor) {
      this.sku = sku;
      this.qty = qty;
      this.priceMinor = priceMinor;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof DocumentItem i)) return false;
      return qty == i.qty && priceMinor == i.priceMinor && Objects.equals(sku, i.sku);
    }

    @Override
    public int hashCode() {
      return Objects.hash(sku, qty, priceMinor);
    }
  }
}
