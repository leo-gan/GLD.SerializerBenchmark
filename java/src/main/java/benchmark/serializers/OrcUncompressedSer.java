package benchmark.serializers;

/** ORC row that sets {@code CompressionKind.NONE}. */
public final class OrcUncompressedSer extends AbstractOrcSer {
  public OrcUncompressedSer() {
    super("orc-uncompressed", true);
  }
}
