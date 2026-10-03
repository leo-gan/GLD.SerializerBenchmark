package benchmark.serializers;

/** Parquet row that sets {@code CompressionCodecName.UNCOMPRESSED}. */
public final class ParquetUncompressedSer extends AbstractParquetSer {
  public ParquetUncompressedSer() {
    super("parquet-uncompressed", true);
  }
}
