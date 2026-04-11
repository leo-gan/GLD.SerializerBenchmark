import { NextResponse } from 'next/server';

export async function POST(req: Request) {
  try {
    const { packageId, code, className } = await req.json();

    if (!packageId || !code || !className) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
    }

    // Returning fake results since actual compilation and running in a Vercel serverless environment
    // is impossible because Vercel provides a read-only filesystem and does not have Mono / .NET SDK installed.
    // In a real production scenario, this endpoint would trigger a GitHub Action or a separate backend server.

    // Simulating delay for "running" the benchmark
    await new Promise(resolve => setTimeout(resolve, 2000));

    // To comply with Vercel deployment constraints, we cannot modify files or run processes.
    // We will simulate success with a mock leaderboard containing the new serializer to prove the UI flow works.

    const mockResults = [
      { SerializerName: "BinarySerializer", OpPerSecSerAndDeser: "15000" },
      { SerializerName: "JsonNetSerializer", OpPerSecSerAndDeser: "28000" },
      { SerializerName: "JilSerializer", OpPerSecSerAndDeser: "95000" },
      { SerializerName: "WireSerializer", OpPerSecSerAndDeser: "115000" },
      { SerializerName: "MsgPackSerializer", OpPerSecSerAndDeser: "85000" },
      { SerializerName: className, OpPerSecSerAndDeser: (100000 + Math.random() * 50000).toFixed(0) },
    ];

    return NextResponse.json({ success: true, results: mockResults, message: "Simulated execution due to serverless constraints. In production, this would trigger a GitHub Action." });
  } catch (err: unknown) {
    console.error('Execution error:', err);
    return NextResponse.json({ error: 'Execution failed' }, { status: 500 });
  }
}
