"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Textarea } from "@/components/ui/textarea";

export default function Home() {
  const [packageId, setPackageId] = useState("");
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<string>("");
  const [generatedCode, setGeneratedCode] = useState<string>("");
  const [className, setClassName] = useState<string>("");
  const [step, setStep] = useState<"input" | "review" | "results">("input");
  const [results, setResults] = useState<Record<string, string>[]>([]);
  const [executeMessage, setExecuteMessage] = useState<string>("");

  const handleGenerate = async () => {
    if (!packageId) return;
    setLoading(true);
    setExecuteMessage("");
    setStatus("Generating C# Wrapper using Gemini...");
    try {
      const res = await fetch("/api/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ packageId }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error);
      setGeneratedCode(data.code);
      setClassName(data.className);
      setStep("review");
    } catch (err: unknown) {
      alert("Error: " + (err as Error).message);
    } finally {
      setLoading(false);
      setStatus("");
    }
  };

  const handleExecute = async () => {
    setLoading(true);
    setExecuteMessage("");
    setStatus("Triggering offline runner (Simulated for Vercel)...");
    try {
      const res = await fetch("/api/execute", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ packageId, code: generatedCode, className }),
      });
      const data = await res.json();
      if (data.error) {
         throw new Error(data.error);
      }
      setResults(data.results || []);
      setExecuteMessage(data.message || "");
      setStep("results");
    } catch (err: unknown) {
      alert("Error executing benchmark: " + (err as Error).message);
    } finally {
      setLoading(false);
      setStatus("");
    }
  };

  const renderLeaderboard = () => {
    if (results.length === 0) return <p className="text-gray-500" data-testid="empty-results">No results to display. Run a benchmark first, or execution returned empty logs.</p>;

    type Aggregation = { name: string, totalOpSec: number, count: number };
    const aggregated = results.reduce((acc: Record<string, Aggregation>, row: Record<string, string>) => {
        const serName = row.SerializerName;
        if (!serName) return acc;
        if (!acc[serName]) acc[serName] = { name: serName, totalOpSec: 0, count: 0 };
        const ops = parseFloat(row.OpPerSecSerAndDeser || '0');
        if (!isNaN(ops)) {
          acc[serName].totalOpSec += ops;
          acc[serName].count += 1;
        }
        return acc;
    }, {});

    const leaderboardData = Object.values(aggregated).map((item) => ({
        name: item.name,
        avgOpSec: item.count > 0 ? item.totalOpSec / item.count : 0
    })).sort((a, b) => b.avgOpSec - a.avgOpSec);

    return (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Rank</TableHead>
              <TableHead>Serializer</TableHead>
              <TableHead className="text-right">Avg Ops/Sec (Ser + Deser)</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {leaderboardData.map((row, i) => (
              <TableRow key={row.name}>
                <TableCell className="font-medium">{i + 1}</TableCell>
                <TableCell>{row.name}</TableCell>
                <TableCell className="text-right">{row.avgOpSec.toLocaleString(undefined, { maximumFractionDigits: 0 })}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
    );
  };

  return (
    <main className="min-h-screen bg-slate-50 p-8">
      <div className="max-w-5xl mx-auto space-y-8">

        <div className="text-center space-y-2">
            <h1 className="text-4xl font-bold tracking-tight text-slate-900">Serializer Benchmark Leaderboard</h1>
            <p className="text-lg text-slate-600">Discover and compare the performance of .NET Serializers. Add your own below.</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Add New Serializer</CardTitle>
            <CardDescription>Enter a NuGet Package ID to generate an integration and run the benchmark.</CardDescription>
          </CardHeader>
          <CardContent>
            {step === "input" && (
                <div className="flex gap-4">
                  <Input
                    placeholder="e.g. Utf8Json"
                    value={packageId}
                    onChange={(e) => setPackageId(e.target.value)}
                    disabled={loading}
                  />
                  <Button onClick={handleGenerate} disabled={loading || !packageId}>
                    {loading ? "Processing..." : "Generate Integration"}
                  </Button>
                </div>
            )}

            {step === "review" && (
                <div className="space-y-4">
                  <p className="text-sm font-medium text-slate-700">Review & Edit Generated C# Wrapper ({className})</p>
                  <Textarea
                    className="font-mono text-sm h-64"
                    value={generatedCode}
                    onChange={(e) => setGeneratedCode(e.target.value)}
                  />
                  <div className="flex gap-4">
                      <Button variant="outline" onClick={() => setStep("input")} disabled={loading}>Back</Button>
                      <Button onClick={handleExecute} disabled={loading}>
                        {loading ? "Running Benchmark..." : "Run Benchmark"}
                      </Button>
                  </div>
                </div>
            )}

            {status && (
                <div className="mt-4 p-4 bg-blue-50 text-blue-800 rounded-md text-sm animate-pulse">
                    {status}
                </div>
            )}
          </CardContent>
        </Card>

        {step === "results" && (
            <Card>
            <CardHeader>
                <CardTitle>Benchmark Results Leaderboard</CardTitle>
                <CardDescription>Average Operations per Second (Serialization + Deserialization)</CardDescription>
            </CardHeader>
            <CardContent>
                {executeMessage && (
                    <div className="mb-4 p-4 bg-yellow-50 text-yellow-800 rounded-md text-sm">
                        {executeMessage}
                    </div>
                )}
                {renderLeaderboard()}
                <div className="mt-6 flex justify-end">
                    <Button variant="outline" onClick={() => { setStep("input"); setPackageId(""); setExecuteMessage(""); }}>Add Another</Button>
                </div>
            </CardContent>
            </Card>
        )}
      </div>
    </main>
  );
}
