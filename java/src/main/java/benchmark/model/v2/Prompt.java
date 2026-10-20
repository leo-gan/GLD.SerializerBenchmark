package benchmark.model.v2;

import java.io.Serializable;
import java.util.Arrays;
import java.util.Objects;

/** Padded LLM inputs (type_id=prompt). Each list length is {@code batch * seq}. */
public final class Prompt implements Serializable {
  private static final long serialVersionUID = 1L;

  public int batch;
  public int seq;
  public long[] inputIds = new long[0];
  public long[] attentionMask = new long[0];
  public long[] positionIds = new long[0];

  public Prompt() {}

  public Prompt(int batch, int seq, long[] inputIds, long[] attentionMask, long[] positionIds) {
    this.batch = batch;
    this.seq = seq;
    this.inputIds = inputIds != null ? inputIds : new long[0];
    this.attentionMask = attentionMask != null ? attentionMask : new long[0];
    this.positionIds = positionIds != null ? positionIds : new long[0];
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Prompt p)) return false;
    return batch == p.batch
        && seq == p.seq
        && Arrays.equals(inputIds, p.inputIds)
        && Arrays.equals(attentionMask, p.attentionMask)
        && Arrays.equals(positionIds, p.positionIds);
  }

  @Override
  public int hashCode() {
    int result = Objects.hash(batch, seq);
    result = 31 * result + Arrays.hashCode(inputIds);
    result = 31 * result + Arrays.hashCode(attentionMask);
    result = 31 * result + Arrays.hashCode(positionIds);
    return result;
  }
}
