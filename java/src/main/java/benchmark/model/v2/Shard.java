package benchmark.model.v2;

import java.io.Serializable;
import java.util.Arrays;
import java.util.Objects;

/**
 * One transformer block (type_id=shard). Weights are row-major float32.
 * {@code tokEmb} is vocab*hidden, {@code attn} is hidden*hidden, {@code ffnWeight} is ffn*hidden,
 * and {@code norm} is hidden.
 */
public final class Shard implements Serializable {
  private static final long serialVersionUID = 1L;

  public int vocab;
  public int hidden;
  public int ffn;
  public float[] tokEmb = new float[0];
  public float[] attn = new float[0];
  public float[] ffnWeight = new float[0];
  public float[] norm = new float[0];

  public Shard() {}

  public Shard(
      int vocab, int hidden, int ffn, float[] tokEmb, float[] attn, float[] ffnWeight, float[] norm) {
    this.vocab = vocab;
    this.hidden = hidden;
    this.ffn = ffn;
    this.tokEmb = tokEmb != null ? tokEmb : new float[0];
    this.attn = attn != null ? attn : new float[0];
    this.ffnWeight = ffnWeight != null ? ffnWeight : new float[0];
    this.norm = norm != null ? norm : new float[0];
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Shard s)) return false;
    return vocab == s.vocab
        && hidden == s.hidden
        && ffn == s.ffn
        && TensorMatrix.sameBits(tokEmb, s.tokEmb)
        && TensorMatrix.sameBits(attn, s.attn)
        && TensorMatrix.sameBits(ffnWeight, s.ffnWeight)
        && TensorMatrix.sameBits(norm, s.norm);
  }

  @Override
  public int hashCode() {
    int result = Objects.hash(vocab, hidden, ffn);
    result = 31 * result + Arrays.hashCode(tokEmb);
    result = 31 * result + Arrays.hashCode(attn);
    result = 31 * result + Arrays.hashCode(ffnWeight);
    result = 31 * result + Arrays.hashCode(norm);
    return result;
  }
}
