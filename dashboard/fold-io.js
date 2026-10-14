/**
 * One published parent per serializer, data type, and instance count.
 *
 * Some snapshots still store bytes/string and stream as two groups that share
 * a display name. Rankings use the parent only. Same-size opt-in pairs average
 * the two levels and keep both as children. C# Base64 pairs keep the raw-byte
 * level as the parent; the string level is a child only when that serializer
 * is on the opt-in list. A group that is already mode "published" is left as
 * written, so folding twice does not drop its children.
 *
 * Rules match analysis/src/benchmark_analysis/fold_io.py and config/dimensions.yaml.
 */

const IN_MEMORY = new Set(['bytes', 'string', 'buffer']);

/** Opt-in second level. level "stream" averages; level "string" is the C# Base64 child. */
export const FOLD_OPT_IN = [
  { language: 'c', serializer: 'ion-c', level: 'stream' },
  { language: 'c', serializer: 'yyjson', level: 'stream' },
  { language: 'cpp', serializer: 'arduinojson', level: 'stream' },
  { language: 'cpp', serializer: 'cereal', level: 'stream' },
  { language: 'cpp', serializer: 'rapidjson', level: 'stream' },
  { language: 'csharp', serializer: 'BinaryPack', level: 'string' },
  { language: 'csharp', serializer: 'FlatSharp', level: 'string' },
  { language: 'csharp', serializer: 'Google.Protobuf', level: 'string' },
  { language: 'csharp', serializer: 'GroBuf', level: 'string' },
  { language: 'csharp', serializer: 'Hyperion', level: 'string' },
  { language: 'csharp', serializer: 'LightProto', level: 'string' },
  { language: 'csharp', serializer: 'MS Binary', level: 'string' },
  { language: 'csharp', serializer: 'MS Bond Compact', level: 'string' },
  { language: 'csharp', serializer: 'MS Bond Fast', level: 'string' },
  { language: 'csharp', serializer: 'MS DataContract', level: 'string' },
  { language: 'csharp', serializer: 'MemoryPack', level: 'string' },
  { language: 'csharp', serializer: 'MessagePack-CSharp', level: 'string' },
  { language: 'csharp', serializer: 'Migrant', level: 'string' },
  { language: 'csharp', serializer: 'Nerdbank.MessagePack', level: 'string' },
  { language: 'csharp', serializer: 'NetSerializer', level: 'string' },
  { language: 'csharp', serializer: 'ProtoBuf', level: 'string' },
  { language: 'csharp', serializer: 'ShapeShift.Json', level: 'stream' },
  { language: 'csharp', serializer: 'ShapeShift.MsgPack', level: 'string' },
  { language: 'csharp', serializer: 'ZeroFormatter', level: 'string' },
  { language: 'go', serializer: 'encoding/json', level: 'stream' },
  { language: 'go', serializer: 'fxamacker/cbor', level: 'stream' },
  { language: 'go', serializer: 'goccy/go-json', level: 'stream' },
  { language: 'go', serializer: 'hamba/avro', level: 'stream' },
  { language: 'go', serializer: 'jsoniter', level: 'stream' },
  { language: 'go', serializer: 'kelindar/binary', level: 'stream' },
  { language: 'go', serializer: 'segmentio/encoding/json', level: 'stream' },
  { language: 'go', serializer: 'shamaton/msgpack', level: 'stream' },
  { language: 'go', serializer: 'shamaton/msgpack (array)', level: 'stream' },
  { language: 'go', serializer: 'sonic', level: 'stream' },
  { language: 'go', serializer: 'ugorji/cbor', level: 'stream' },
  { language: 'go', serializer: 'ugorji/json', level: 'stream' },
  { language: 'go', serializer: 'ugorji/msgpack', level: 'stream' },
  { language: 'go', serializer: 'vmihailenco/msgpack', level: 'stream' },
];

/** Serializers whose only timed API is a file. One stream parent, no bytes row. */
export const FOLD_FILE_ONLY = [
  { language: 'fortran', serializer: 'netcdf-fortran' },
  { language: 'fortran', serializer: 'adios2' },
];

const DEFAULT_CONFIG = {
  optIn: FOLD_OPT_IN,
  fileOnly: FOLD_FILE_ONLY,
  base64Ratio: 0.75,
  base64Tolerance: 0.05,
};

function modeOf(group) {
  return String(group?.mode || '').trim().toLowerCase();
}

function pairKey(language, serializer) {
  return `${language || ''}\0${serializer || ''}`;
}

function indexPairs(rows) {
  const map = new Map();
  for (const row of rows || []) {
    map.set(pairKey(row.language, row.serializer), row);
  }
  return map;
}

function bucketKey(group) {
  return [
    group?.language || '',
    group?.serializer || '',
    group?.test_data || '',
    group?.type_config_hash || '',
    group?.data_type_instance_count ?? '',
  ].join('\0');
}

function sizeOf(group) {
  const variants = group?.variants;
  if (variants && typeof variants === 'object') {
    for (const policy of ['iqr_1.5', 'all']) {
      const metrics = variants[policy];
      if (metrics && metrics.median_size_bytes) return Number(metrics.median_size_bytes);
    }
    for (const metrics of Object.values(variants)) {
      if (metrics && typeof metrics === 'object' && metrics.median_size_bytes) {
        return Number(metrics.median_size_bytes);
      }
    }
    return 0;
  }
  return Number(group?.median_size_bytes) || 0;
}

function isBase64Pair(levels, ratio, tolerance) {
  const sizes = levels.map(sizeOf).filter((size) => size > 0);
  if (sizes.length < 2) return false;
  const small = Math.min(...sizes);
  const large = Math.max(...sizes);
  return Math.abs(small / large - ratio) <= tolerance;
}

function inMemory(levels) {
  return levels.find((group) => IN_MEMORY.has(modeOf(group))) || levels[0];
}

function rawBytes(levels) {
  let best = levels[0];
  let bestSize = sizeOf(best);
  for (const group of levels.slice(1)) {
    const size = sizeOf(group);
    if (size < bestSize) {
      best = group;
      bestSize = size;
    }
  }
  return best;
}

function child(group, level) {
  const out = {
    level,
    mode: group.mode,
  };
  if (group.StreamMode) out.StreamMode = group.StreamMode;
  if (group.variants && typeof group.variants === 'object') {
    out.variants = structuredClone(group.variants);
    return out;
  }
  for (const [key, value] of Object.entries(group)) {
    if (key === 'mode' || key === 'StreamMode' || key === 'variants' || key === 'optional' || key === 'io_parent') {
      continue;
    }
    out[key] = value && typeof value === 'object' ? structuredClone(value) : value;
  }
  return out;
}

function averageMetrics(parts) {
  const out = {};
  const keys = new Set();
  for (const part of parts) {
    for (const key of Object.keys(part)) keys.add(key);
  }
  const count = parts.length;
  for (const key of keys) {
    if (key === 'filter' || key.startsWith('effect_vs_fastest')) continue;
    const values = [];
    let numeric = true;
    for (const part of parts) {
      const value = part[key];
      if (typeof value !== 'number' || !Number.isFinite(value)) {
        numeric = false;
        break;
      }
      values.push(value);
    }
    if (numeric && values.length === count) {
      out[key] = values.reduce((sum, value) => sum + value, 0) / count;
    }
  }
  if (parts[0] && parts[0].filter && typeof parts[0].filter === 'object') {
    out.filter = structuredClone(parts[0].filter);
  }
  const total = out.avg_time_total_ns || out.total_mean_ns;
  if (typeof total === 'number' && total > 0) out.avg_ops_per_sec = 1e9 / total;
  if (typeof out.total_max_ns === 'number' && out.total_max_ns > 0) {
    out.min_ops_per_sec = 1e9 / out.total_max_ns;
  }
  if (typeof out.total_min_ns === 'number' && out.total_min_ns > 0) {
    out.max_ops_per_sec = 1e9 / out.total_min_ns;
  }
  return out;
}

function withOptional(group, optional, how) {
  const parent = structuredClone(group);
  parent.optional = optional;
  parent.io_parent = how;
  parent.mode = 'published';
  return parent;
}

function usesVariants(levels) {
  return levels.some((group) => group.variants && typeof group.variants === 'object');
}

const FLAT_IDENTITY = new Set([
  'serializer',
  'test_data',
  'type_config_hash',
  'data_type_instance_count',
  'mode',
  'language',
  'serializer_version',
  'standard',
  'data_set',
  'StreamMode',
  'variants',
  'optional',
  'io_parent',
  'level',
  'io_child',
]);

function metricFields(group) {
  const out = {};
  for (const [key, value] of Object.entries(group)) {
    if (!FLAT_IDENTITY.has(key)) out[key] = value;
  }
  return out;
}

function averageGroup(levels) {
  const parent = structuredClone(inMemory(levels));
  if (usesVariants(levels)) {
    const policies = new Set();
    for (const group of levels) {
      for (const policy of Object.keys(group.variants || {})) policies.add(policy);
    }
    const variants = {};
    for (const policy of policies) {
      const parts = [];
      for (const group of levels) {
        const metrics = group.variants && group.variants[policy];
        if (metrics && typeof metrics === 'object') parts.push(metrics);
      }
      if (parts.length === levels.length) variants[policy] = averageMetrics(parts);
    }
    parent.variants = variants;
  } else {
    const averaged = averageMetrics(levels.map(metricFields));
    for (const key of Object.keys(metricFields(parent))) {
      if (!(key in averaged)) delete parent[key];
    }
    Object.assign(parent, averaged);
  }
  parent.optional = levels.map((group) => {
    const mode = modeOf(group);
    return child(group, mode === 'stream' ? 'stream' : (mode || 'bytes'));
  });
  parent.io_parent = 'average';
  parent.mode = 'published';
  return parent;
}

/**
 * @param {object[]} groups
 * @param {{ optIn?: {language: string, serializer: string, level: string}[], fileOnly?: {language: string, serializer: string}[], base64Ratio?: number, base64Tolerance?: number }} [config]
 * @returns {object[]}
 */
export function foldIoGroups(groups, config = {}) {
  const optIn = indexPairs(config.optIn || DEFAULT_CONFIG.optIn);
  const fileOnly = indexPairs(config.fileOnly || DEFAULT_CONFIG.fileOnly);
  const ratio = config.base64Ratio ?? DEFAULT_CONFIG.base64Ratio;
  const tolerance = config.base64Tolerance ?? DEFAULT_CONFIG.base64Tolerance;

  const buckets = new Map();
  const order = [];
  for (const group of groups || []) {
    if (!group) continue;
    const key = bucketKey(group);
    if (!buckets.has(key)) {
      order.push(key);
      buckets.set(key, []);
    }
    buckets.get(key).push(group);
  }

  const folded = [];
  for (const key of order) {
    const levels = buckets.get(key);
    const language = levels[0]?.language;
    const serializer = levels[0]?.serializer;
    const modes = new Set(levels.map(modeOf));
    if (modes.size === 1 && modes.has('stream')) {
      if (fileOnly.has(pairKey(language, serializer))) {
        folded.push(withOptional(levels[0], [], 'file'));
      }
      continue;
    }
    if (levels.length === 1) {
      if (modeOf(levels[0]) === 'published') folded.push(levels[0]);
      else folded.push(withOptional(levels[0], [], 'single'));
      continue;
    }
    const chosen = optIn.get(pairKey(language, serializer));
    if (language === 'csharp' && isBase64Pair(levels, ratio, tolerance)) {
      const parent = withOptional(rawBytes(levels), [], 'raw_bytes');
      if (chosen && chosen.level === 'string') {
        const stringLevel = levels.find((group) => modeOf(group) === 'string');
        if (stringLevel) parent.optional = [child(stringLevel, 'string')];
      }
      folded.push(parent);
      continue;
    }
    if (chosen && chosen.level === 'stream') {
      folded.push(averageGroup(levels));
      continue;
    }
    folded.push(withOptional(inMemory(levels), [], 'in_memory'));
  }
  return folded;
}
