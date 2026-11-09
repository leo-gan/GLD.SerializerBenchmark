/**
 * Turn a raw timing CSV into the flat groups the Overview page can chart.
 * This is the historical-run upload path, not the published stats document.
 */

export function parseCSV(text) {
  const lines = String(text || '').trim().split(/\r?\n/);
  if (lines.length < 2) return [];
  const headers = parseCSVLine(lines[0]);
  const records = [];
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const values = parseCSVLine(lines[i]);
    const rec = {};
    headers.forEach((h, idx) => {
      rec[h] = values[idx];
    });
    records.push(rec);
  }
  return records;
}

function parseCSVLine(line) {
  const result = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else inQuotes = !inQuotes;
    } else if (ch === ',' && !inQuotes) {
      result.push(cur);
      cur = '';
    } else cur += ch;
  }
  result.push(cur);
  return result;
}

function mean(arr) {
  if (!arr || !arr.length) return null;
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}

function median(arr) {
  if (!arr || !arr.length) return null;
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

export function aggregateCSVRecords(records) {
  const map = new Map();
  for (const record of records || []) {
    const serializer = record.Serializer || record.serializer;
    const testData = record.TestData || record.test_data || record.DataType;
    const mode = record.Mode || record.mode || 'bytes';
    if (!serializer) continue;
    const key = `${serializer}|${testData}|${mode}`;
    if (!map.has(key)) {
      map.set(key, {
        serializer,
        test_data: testData,
        mode,
        times: [],
        ser: [],
        deser: [],
        sizes: [],
        ops: [],
        fidelities: [],
      });
    }
    const group = map.get(key);
    const total = Number(record.TotalTimeNs || record.total_time_ns || record.TimeNs);
    const ser = Number(record.SerTimeNs || record.ser_time_ns);
    const deser = Number(record.DeserTimeNs || record.deser_time_ns);
    const size = Number(record.SizeBytes || record.size_bytes || record.PayloadSize);
    const ops = Number(record.OpsPerSec || record.ops_per_sec);
    const fidelity = Number(record.FidelityScore || record.fidelity);
    if (Number.isFinite(total)) group.times.push(total);
    if (Number.isFinite(ser)) group.ser.push(ser);
    if (Number.isFinite(deser)) group.deser.push(deser);
    if (Number.isFinite(size)) group.sizes.push(size);
    if (Number.isFinite(ops)) group.ops.push(ops);
    if (Number.isFinite(fidelity)) group.fidelities.push(fidelity);
  }

  const groups = [];
  for (const group of map.values()) {
    if (!group.times.length && !group.ops.length) continue;
    const avgTime = mean(group.times);
    const avgOps = group.ops.length > 0 ? mean(group.ops) : avgTime > 0 ? 1e9 / avgTime : 0;
    groups.push({
      serializer: group.serializer,
      test_data: group.test_data,
      mode: group.mode,
      avg_time_total_ns: avgTime,
      avg_time_ser_ns: mean(group.ser),
      avg_time_deser_ns: mean(group.deser),
      avg_ops_per_sec: avgOps,
      median_size_bytes: median(group.sizes),
      mean_fidelity: group.fidelities.length ? mean(group.fidelities) : null,
      runs: Math.max(group.times.length, group.ops.length),
    });
  }
  return groups;
}
