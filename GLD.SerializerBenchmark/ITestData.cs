using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace GLD.SerializerBenchmark
{
    public interface ITestData
    {
        ITestData Generate();
        List<string> Compare(ITestData comparable);
    }
}
