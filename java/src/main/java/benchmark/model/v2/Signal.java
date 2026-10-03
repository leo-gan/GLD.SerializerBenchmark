package benchmark.model.v2;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

/**
 * Fixed fields, then strings, then a repeating group (type_id=signal).
 * leg_pad is always 0 and is not drawn from the PRNG.
 */
public final class Signal implements Serializable {
  private static final long serialVersionUID = 1L;

  public long seq;
  public long ts;
  public long priceMantissa;
  public int qty;
  public int flags;
  public String symbol;
  public String venue;
  public List<SignalLeg> legs = new ArrayList<>();

  public Signal() {}

  public Signal(
      long seq,
      long ts,
      long priceMantissa,
      int qty,
      int flags,
      String symbol,
      String venue,
      List<SignalLeg> legs) {
    this.seq = seq;
    this.ts = ts;
    this.priceMantissa = priceMantissa;
    this.qty = qty;
    this.flags = flags;
    this.symbol = symbol;
    this.venue = venue;
    this.legs = legs != null ? legs : new ArrayList<>();
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Signal s)) return false;
    return seq == s.seq
        && ts == s.ts
        && priceMantissa == s.priceMantissa
        && qty == s.qty
        && flags == s.flags
        && Objects.equals(symbol, s.symbol)
        && Objects.equals(venue, s.venue)
        && Objects.equals(legs, s.legs);
  }

  @Override
  public int hashCode() {
    return Objects.hash(seq, ts, priceMantissa, qty, flags, symbol, venue, legs);
  }

  public static final class SignalLeg implements Serializable {
    private static final long serialVersionUID = 1L;
    public long legId;
    public int legQty;
    public int legPad;

    public SignalLeg() {}

    public SignalLeg(long legId, int legQty, int legPad) {
      this.legId = legId;
      this.legQty = legQty;
      this.legPad = legPad;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof SignalLeg l)) return false;
      return legId == l.legId && legQty == l.legQty && legPad == l.legPad;
    }

    @Override
    public int hashCode() {
      return Objects.hash(legId, legQty, legPad);
    }
  }
}
