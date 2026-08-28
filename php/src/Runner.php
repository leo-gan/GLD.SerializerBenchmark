<?php

declare(strict_types=1);

namespace Benchmark;

use Benchmark\Serializers\Registry;
use Benchmark\Serializers\Serializer;

require dirname(__DIR__) . '/vendor/autoload.php';

$repetitions = (int) ($argv[1] ?? 10);
$serFilter = (string) ($argv[2] ?? '');
$dataFilter = strtolower((string) ($argv[3] ?? ''));

$projectRoot = dirname(__DIR__, 2);
$logDirEnv = getenv('LOG_DIR') ?: ($projectRoot . '/logs');
$logDir = str_ends_with(rtrim($logDirEnv, '/'), 'php') ? $logDirEnv : ($logDirEnv . '/php');
if (!is_dir($logDir) && !mkdir($logDir, 0777, true) && !is_dir($logDir)) {
    fwrite(STDERR, "cannot create $logDir\n");
    exit(1);
}

$ts = getenv('BENCHMARK_TS') ?: date('Y-m-d-His');
$logPath = $logDir . '/' . $ts . '.csv';
$errPath = $logDir . '/' . $ts . '.errors.csv';

$header = 'Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode,DataTypeInstanceCount,TypeConfigHash,RunOrder,SchedulePosition,SizeGzip,SizeZstd' . "\n";
$lines = [$header];
$errors = ['TestDataName,SerializerName,StringOrStream,Repetition,ErrorText' . "\n"];

$resolved = resolveRunConfig($projectRoot);
$seed = (int) (getenv('BENCHMARK_SEED') ?: ($resolved['seed'] ?? 42));
$cells = $resolved['cells'] ?? [];
if ($dataFilter !== '') {
    $cells = array_values(array_filter(
        $cells,
        static fn ($c) => str_contains(strtolower((string) ($c['type_id'] ?? '')), $dataFilter),
    ));
}
$modesRaw = $resolved['execution']['io_modes'] ?? ['bytes'];
$modes = [];
foreach ($modesRaw as $m) {
    $m = strtolower((string) $m);
    if ($m === 'bytes' || $m === 'stream') {
        $modes[$m] = $m;
    }
}
$modes = array_values($modes);
if ($modes === []) {
    $modes = ['bytes'];
}

$serializers = Registry::select($serFilter);
$strategy = Schedule::strategy();
$recordRO = Schedule::recordRunOrder();

fwrite(STDERR, sprintf(
    "[PROGRESS] PHP Data Model v2: %d serializers, %d cells, %d reps, modes=[%s] schedule=%s\n",
    count($serializers),
    count($cells),
    $repetitions,
    implode(',', $modes),
    $strategy,
));

$runOrder = 0;
foreach ($cells as $cell) {
    $n = (int) ($cell['data_type_instance_count'] ?? 1);
    $typeId = (string) $cell['type_id'];
    $cfg = $cell['type_config'] ?? [];
    $hash = (string) ($cell['type_config_hash'] ?? '');
    $value = $n === 1
        ? DataV2::makeOne($typeId, $cfg, $seed, 0)
        : DataV2::instances($typeId, $cfg, $seed, $n);
    fwrite(STDERR, "[PROGRESS] Testing Data: {$typeId} (N={$n})\n");

    $ready = [];
    foreach ($serializers as $ser) {
        try {
            $ser->prepare($value);
            $gz = 0;
            $zs = 0;
            try {
                $sample = $ser->serializeBytes($value);
                $gz = strlen(gzencode($sample, 6) ?: '');
            } catch (\Throwable) {
                $gz = 0;
            }
            $ready[$ser->name()] = ['ser' => $ser, 'gz' => $gz, 'zs' => $zs];
        } catch (\Throwable $e) {
            fwrite(STDERR, sprintf("[ERROR] prepare %s / %s: %s\n", $ser->name(), $typeId, $e->getMessage()));
            $errors[] = csvRow([$typeId, $ser->name(), 'prepare', '0', $e->getMessage()]);
        }
    }

    foreach ($modes as $mode) {
        for ($rep = 0; $rep < $repetitions; $rep++) {
            $names = array_keys($ready);
            if ($strategy !== 'none') {
                $names = Schedule::shuffle($names, $seed, $typeId, $n, $hash, $mode, $rep);
            }
            $pos = 0;
            foreach ($names as $name) {
                /** @var Serializer $ser */
                $ser = $ready[$name]['ser'];
                $pos++;
                $runOrder++;
                try {
                    if ($mode === 'bytes') {
                        $t0 = hrtime(true);
                        $bytes = $ser->serializeBytes($value);
                        $t1 = hrtime(true);
                        $back = $ser->deserializeBytes($bytes);
                        $t2 = hrtime(true);
                        $size = strlen($bytes);
                    } else {
                        $buf = fopen('php://memory', 'r+b');
                        $t0 = hrtime(true);
                        $size = $ser->serializeStream($value, $buf);
                        $t1 = hrtime(true);
                        rewind($buf);
                        $back = $ser->deserializeStream($buf);
                        $t2 = hrtime(true);
                        fclose($buf);
                    }
                    $serNs = $t1 - $t0;
                    $deserNs = $t2 - $t1;
                    $tot = $serNs + $deserNs;
                    $ok = fidelity($value, $back) ? 1.0 : 0.0;
                    if ($ok < 1.0) {
                        $errors[] = csvRow([$typeId, $name, $mode, (string) $rep, 'fidelity']);
                    }
                    $lines[] = csvRow([
                        'php',
                        $mode,
                        $typeId,
                        (string) $repetitions,
                        (string) $rep,
                        $name,
                        $ser->version(),
                        (string) $serNs,
                        (string) $deserNs,
                        (string) $size,
                        (string) $tot,
                        $serNs > 0 ? formatOps($serNs) : '',
                        $deserNs > 0 ? formatOps($deserNs) : '',
                        $tot > 0 ? formatOps($tot) : '',
                        '0',
                        (string) $ok,
                        'message',
                        $ser->streamMode(),
                        (string) $n,
                        $hash,
                        $recordRO ? (string) $runOrder : '',
                        (string) $pos,
                        (string) $ready[$name]['gz'],
                        (string) $ready[$name]['zs'],
                    ]);
                } catch (\Throwable $e) {
                    $errors[] = csvRow([$typeId, $name, $mode, (string) $rep, $e->getMessage()]);
                }
            }
        }
    }
}

file_put_contents($logPath, implode('', $lines));
if (count($errors) > 1) {
    file_put_contents($errPath, implode('', $errors));
}
fwrite(STDERR, "[PROGRESS] Complete. Results: {$logPath}\n");

function resolveRunConfig(string $projectRoot): array
{
    $runCfg = getenv('BENCHMARK_RUN_CONFIG') ?: ($projectRoot . '/config/library/default.yaml');
    if (!str_starts_with($runCfg, '/')) {
        $fromRepo = $projectRoot . '/' . ltrim($runCfg, './');
        $runCfg = is_file($fromRepo) ? $fromRepo : $runCfg;
    }
    $seed = getenv('BENCHMARK_SEED') ?: '42';
    $script = $projectRoot . '/scripts/resolve_run_config.py';
    $cmd = [
        'python3',
        $script,
        $runCfg,
        '--seed',
        $seed,
    ];
    $env = [];
    foreach (getenv() as $k => $v) {
        if (is_string($v)) {
            $env[$k] = $v;
        }
    }
    $prev = $env['PYTHONPATH'] ?? '';
    $env['PYTHONPATH'] = $projectRoot . '/analysis/src' . ($prev !== '' ? ':' . $prev : '');
    $proc = proc_open($cmd, [1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes, $projectRoot, $env);
    if (!is_resource($proc)) {
        throw new \RuntimeException('resolve_run_config spawn failed');
    }
    $out = stream_get_contents($pipes[1]);
    $err = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $code = proc_close($proc);
    if ($code !== 0) {
        throw new \RuntimeException('resolve_run_config failed: ' . $err . $out);
    }
    return json_decode($out, true, 512, JSON_THROW_ON_ERROR);
}

function fidelity(mixed $a, mixed $b): bool
{
    if (is_array($a) && is_array($b)) {
        if (count($a) !== count($b)) {
            return false;
        }
        foreach ($a as $k => $x) {
            if (!array_key_exists($k, $b) || !fidelity($x, $b[$k])) {
                return false;
            }
        }
        return true;
    }
    if (is_bool($a)) {
        if (is_bool($b)) {
            return $a === $b;
        }
        return $a === filter_var($b, FILTER_VALIDATE_BOOLEAN);
    }
    if (is_int($a) && is_numeric($b)) {
        return $a === (int) $b;
    }
    if (is_float($a) || is_float($b) || (is_numeric($a) && is_numeric($b) && (is_string($a) || is_string($b)))) {
        return abs((float) $a - (float) $b) < 1e-8;
    }
    return $a === $b;
}

function formatOps(int $ns): string
{
    return number_format(1_000_000_000 / $ns, 6, '.', '');
}

function csvRow(array $cols): string
{
    $esc = [];
    foreach ($cols as $c) {
        $s = (string) $c;
        if (str_contains($s, ',') || str_contains($s, '"') || str_contains($s, "\n")) {
            $s = '"' . str_replace('"', '""', $s) . '"';
        }
        $esc[] = $s;
    }
    return implode(',', $esc) . "\n";
}
