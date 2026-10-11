using System;
using System.IO;
using System.Text;
using GLD.SerializerBenchmark.TestData.V2;
using PureHDF;
using PureHDF.Selections;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// PureHDF, a managed HDF5 reader and writer. One contiguous float64 dataset
    /// named grid. grid_window reads a hyperslab. The string API carries the file
    /// bytes as Latin-1 so the reported size is the file length.
    /// </summary>
    internal class PureHdfSerializerSer : SerDeser
    {
        bool _window;
        int _nx, _ny, _x0, _y0, _wx, _wy;

        public override string Name => "PureHDF";

        public override bool Supports(string testDataName) =>
            testDataName is "grid" or "grid_window";

        public override void PrepareData(object data)
        {
            var grid = (Grid)data;
            _window = string.Equals(FixtureName, "grid_window", StringComparison.Ordinal);
            _nx = grid.Nx;
            _ny = grid.Ny;
            _x0 = grid.X0;
            _y0 = grid.Y0;
            _wx = grid.Wx;
            _wy = grid.Wy;
        }

        public override string Serialize(object serializable) =>
            Encoding.Latin1.GetString(Write((Grid)serializable));

        public override object Deserialize(string serialized) =>
            Read(Encoding.Latin1.GetBytes(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = Write((Grid)serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            using var copy = new MemoryStream();
            inputStream.CopyTo(copy);
            return Read(copy.ToArray());
        }

        static double[] ValuesToXy(Grid grid)
        {
            var xy = new double[grid.Nx * grid.Ny];
            for (var y = 0; y < grid.Ny; y++)
            {
                for (var x = 0; x < grid.Nx; x++)
                    xy[x * grid.Ny + y] = grid.Values[y * grid.Nx + x];
            }
            return xy;
        }

        static double[] XyToValues(double[] xy, int nx, int ny)
        {
            var values = new double[nx * ny];
            for (var y = 0; y < ny; y++)
            {
                for (var x = 0; x < nx; x++)
                    values[y * nx + x] = xy[x * ny + y];
            }
            return values;
        }

        static byte[] Write(Grid grid)
        {
            var dataset = new H5Dataset<double[]>(
                ValuesToXy(grid),
                fileDims: new ulong[] { (ulong)grid.Nx, (ulong)grid.Ny });
            var file = new H5File { ["grid"] = dataset };
            using var stream = new MemoryStream();
            file.Write(stream);
            return stream.ToArray();
        }

        double[] Read(byte[] bytes)
        {
            using var stream = new MemoryStream(bytes, writable: false);
            var file = H5File.Open(stream, leaveOpen: true);
            var dataset = file.Dataset("grid");
            double[] xy;
            int nx, ny;
            if (_window)
            {
                var selection = new HyperslabSelection(
                    rank: 2,
                    starts: new ulong[] { (ulong)_x0, (ulong)_y0 },
                    strides: new ulong[] { 1, 1 },
                    counts: new ulong[] { (ulong)_wx, (ulong)_wy },
                    blocks: new ulong[] { 1, 1 });
                xy = dataset.Read<double[]>(fileSelection: selection);
                nx = _wx;
                ny = _wy;
            }
            else
            {
                xy = dataset.Read<double[]>();
                nx = _nx;
                ny = _ny;
            }
            return XyToValues(xy, nx, ny);
        }
    }
}
