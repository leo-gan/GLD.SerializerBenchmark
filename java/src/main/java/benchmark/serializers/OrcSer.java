package benchmark.serializers;

/** ORC row. Does not call {@code WriterOptions.compress}. */
public final class OrcSer extends AbstractOrcSer {
  public OrcSer() {
    super("orc", false);
  }
}
