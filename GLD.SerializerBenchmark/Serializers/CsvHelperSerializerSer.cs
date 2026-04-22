using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using CsvHelper;
using CsvHelper.Configuration;

namespace GLD.SerializerBenchmark.Serializers
{
    // CsvHelper
    internal class CsvHelperSerializerSer : SerDeser
    {
        public override string Name => "CsvHelper";

        public override bool Supports(string testDataName)
        {
            // CsvHelper only works with simple flat objects (Integer, SimpleObject)
            // Cannot handle nested objects, arrays, or circular references
            return testDataName == "Integer" || testDataName == "SimpleObject";
        }

        public override string Serialize(object serializable)
        {
            using var writer = new StringWriter();
            using var csv = new CsvWriter(writer, new CsvConfiguration(System.Globalization.CultureInfo.InvariantCulture));
            
            // Serialize as a single-item list
            var listType = typeof(List<>).MakeGenericType(_primaryType);
            var list = (IList)Activator.CreateInstance(listType);
            list.Add(serializable);
            
            csv.WriteRecords(list);
            return writer.ToString();
        }
        
        public override object Deserialize(string serialized)
        {
            using var reader = new StringReader(serialized);
            using var csv = new CsvReader(reader, new CsvConfiguration(System.Globalization.CultureInfo.InvariantCulture));
            
            // Use reflection to call GetRecords<T>() with _primaryType
            var method = typeof(CsvReader).GetMethods()
                .First(m => m.Name == "GetRecords" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 0);
            var genericMethod = method.MakeGenericMethod(_primaryType);
            var records = genericMethod.Invoke(csv, null);
            
            // Get first record or default
            var enumerable = records as IEnumerable;
            foreach (var record in enumerable)
            {
                return record;
            }
            return null;
        }
        
        public override void Serialize(object serializable, Stream outputStream)
        {
            using var writer = new StreamWriter(outputStream, System.Text.Encoding.UTF8, 1024, true);
            using var csv = new CsvWriter(writer, new CsvConfiguration(System.Globalization.CultureInfo.InvariantCulture));
            
            var listType = typeof(List<>).MakeGenericType(_primaryType);
            var list = (IList)Activator.CreateInstance(listType);
            list.Add(serializable);
            
            csv.WriteRecords(list);
        }
        
        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var reader = new StreamReader(inputStream, System.Text.Encoding.UTF8, false, 1024, true);
            using var csv = new CsvReader(reader, new CsvConfiguration(System.Globalization.CultureInfo.InvariantCulture));
            
            var method = typeof(CsvReader).GetMethods()
                .First(m => m.Name == "GetRecords" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 0);
            var genericMethod = method.MakeGenericMethod(_primaryType);
            var records = genericMethod.Invoke(csv, null);
            
            var enumerable = records as IEnumerable;
            foreach (var record in enumerable)
            {
                return record;
            }
            return null;
        }
    }
}
