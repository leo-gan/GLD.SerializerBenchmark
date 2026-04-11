import { NextResponse } from 'next/server';
import { GoogleGenAI } from '@google/genai';

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

export async function POST(req: Request) {
  try {
    const { packageId } = await req.json();

    if (!packageId) {
      return NextResponse.json({ error: 'Package ID is required' }, { status: 400 });
    }

    const prompt = `
You are an expert C# developer. We are adding a new serializer to the benchmark project "GLD.SerializerBenchmark".
The user wants to add the NuGet package: "${packageId}".

Write a C# class that implements the \`ISerDeser\` interface for this new serializer.
The \`ISerDeser\` interface looks like this:

\`\`\`csharp
using System;
using System.Collections.Generic;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal interface ISerDeser
    {
        string Name { get; }
        void Initialize(Type serializablePrimaryType, List<Type> serializableSecondaryTypes = null);
        string Serialize(object serializable);
        object Deserialize(string serialized);
        void Serialize(object serializable, Stream outputStream);
        object Deserialize(Stream inputStream);
    }
}
\`\`\`

Requirements:
- The class name should generally end with "Serializer" and avoid special characters (e.g., JsonNetSerializer).
- Provide ONLY the pure string representation of the class name in the first line of your response in this format: CLASS_NAME: YourClassNameSerializer
- Then on the lines following that, provide ONLY the raw C# code. Do NOT wrap it in markdown \`\`\`csharp blocks. Do NOT provide any explanation or extra text.
- Use the namespace \`GLD.SerializerBenchmark.Serializers\`.
- Make the \`Name\` property descriptive of the package.
- In \`Initialize\`, perform any caching of the Type or pre-computations if the specific serializer requires it.
- Implement both string-based and Stream-based Serialize and Deserialize methods.
`;

    console.log("Calling Gemini for package:", packageId);
    const response = await ai.models.generateContent({
        model: 'gemini-2.5-flash',
        contents: prompt,
        config: {
          temperature: 0.2,
        }
    });

    console.log("Received response from Gemini");

    let rawOutput = response.text || '';

    // Clean up markdown wrapping just in case
    rawOutput = rawOutput.replace(/```csharp/g, '').replace(/```/g, '').trim();

    let className = 'GeneratedSerializer';
    const lines = rawOutput.split('\n');

    if (lines[0].startsWith('CLASS_NAME:')) {
        className = lines[0].replace('CLASS_NAME:', '').trim();
        lines.shift();
    }

    const code = lines.join('\n').trim();

    return NextResponse.json({ code, className });
  } catch (err: unknown) {
    console.error('Error generating wrapper:', err);
    const error = err as Error;
    return NextResponse.json({ error: error.message || 'Failed to generate code' }, { status: 500 });
  }
}
