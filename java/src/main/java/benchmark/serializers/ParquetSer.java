package benchmark.serializers;

/** Parquet row. Does not pass {@code withCompressionCodec}. */
public final class ParquetSer extends AbstractParquetSer {
  public ParquetSer() {
    super("parquet", false);
  }
}
