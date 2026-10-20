package benchmark.model.v2;

import java.io.Serializable;
import java.util.Objects;

/** One inference call (type_id=request): id, model name, temperature, and the prompt. */
public final class Request implements Serializable {
  private static final long serialVersionUID = 1L;

  public long requestId;
  public String model;
  public float temperature;
  public Prompt inputs = new Prompt();

  public Request() {}

  public Request(long requestId, String model, float temperature, Prompt inputs) {
    this.requestId = requestId;
    this.model = model;
    this.temperature = temperature;
    this.inputs = inputs != null ? inputs : new Prompt();
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
    if (!(o instanceof Request r)) return false;
    return requestId == r.requestId
        && TensorMatrix.sameBits(temperature, r.temperature)
        && Objects.equals(model, r.model)
        && Objects.equals(inputs, r.inputs);
  }

  @Override
  public int hashCode() {
    return Objects.hash(requestId, model, Float.floatToRawIntBits(temperature), inputs);
  }
}
