package benchmark.model;

/** One named payload used by the runner. */
public final class Fixture {
  public final String name;
  public final Object value;

  public Fixture(String name, Object value) {
    this.name = name;
    this.value = value;
  }
}
