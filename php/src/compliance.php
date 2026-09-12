#!/usr/bin/env php
<?php
/** PHP compliance runner — same catalog as Python. */
declare(strict_types=1);

$root = findRepoRoot();
$autoload = $root . '/php/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
}
$catalog = $root . '/compliance/data';
$jsonOut = null;
$formats = [];
for ($i = 1; $i < $argc; $i++) {
    if (($argv[$i] === '--json-out' || $argv[$i] === '-o') && isset($argv[$i + 1])) {
        $jsonOut = $argv[++$i];
    } elseif (($argv[$i] === '--format' || $argv[$i] === '-f') && isset($argv[$i + 1])) {
        $formats[] = strtolower($argv[++$i]);
    }
}

$suites = loadSuites($catalog);
if ($formats) {
    $want = array_flip($formats);
    $suites = array_values(array_filter($suites, fn($s) => isset($want[strtolower($s['format'])])));
}

$adapters = builtinAdapters();
$byFmt = [];
foreach ($adapters as $a) {
    $byFmt[$a['format']][] = $a;
}

$results = [];
$adapterErrs = [];
foreach ($suites as $suite) {
    $chosen = $byFmt[$suite['format']] ?? [];
    if (!$chosen) {
        $adapterErrs[] = "No adapter registered for format {$suite['format']} ({$suite['standard']} ({$suite['version']}))";
        continue;
    }
    foreach ($chosen as $a) {
        foreach ($suite['cases'] as $c) {
            $results[] = runOne($suite, $c, $a);
        }
    }
}
printSummary($results, $adapterErrs);
if ($jsonOut) {
    writeReport($jsonOut, $results, $adapterErrs);
    fwrite(STDOUT, "\nWrote {$jsonOut}\n");
}

function findRepoRoot(): string
{
    $dir = getcwd();
    for ($i = 0; $i < 8; $i++) {
        if (is_dir($dir . '/compliance/data')) {
            return $dir;
        }
        $parent = dirname($dir);
        if ($parent === $dir) {
            break;
        }
        $dir = $parent;
    }
    fwrite(STDERR, "cannot locate compliance/data\n");
    exit(2);
}

function loadSuites(string $root): array
{
    $suites = [];
    foreach (glob($root . '/*/*.json') ?: [] as $path) {
        if (str_starts_with(basename($path), '_')) {
            continue;
        }
        $raw = json_decode((string) file_get_contents($path), true);
        if (!is_array($raw) || empty($raw['cases']) || empty($raw['format'])) {
            continue;
        }
        $suites[] = $raw;
    }
    if (!$suites) {
        fwrite(STDERR, "no compliance suites under {$root}\n");
        exit(2);
    }
    return $suites;
}

function inputBytes(array $c): string
{
    $enc = $c['input_encoding'] ?? 'utf-8';
    $in = (string) ($c['input'] ?? '');
    if ($enc === 'hex') {
        $compact = preg_replace('/\s+/', '', $in) ?? '';
        return $compact === '' ? '' : (string) hex2bin($compact);
    }
    return $in;
}

function builtinAdapters(): array
{
    $out = [
        ['name' => 'json', 'format' => 'json', 'version' => PHP_VERSION, 'decode' => function (string $b) {
            $v = json_decode($b, true, 512, JSON_THROW_ON_ERROR);
            return $v;
        }],
    ];
    if (class_exists(\Symfony\Component\Yaml\Yaml::class)) {
        $out[] = ['name' => 'yaml', 'format' => 'yaml', 'version' => '', 'decode' => function (string $b) {
            return \Symfony\Component\Yaml\Yaml::parse($b);
        }];
    }
    if (class_exists(\MessagePack\MessagePack::class)) {
        $out[] = ['name' => 'rybakit-msgpack', 'format' => 'msgpack', 'version' => '', 'decode' => function (string $b) {
            return \MessagePack\MessagePack::unpack($b);
        }];
    }
    if (class_exists(\Google\Protobuf\Internal\CodedInputStream::class)) {
        $out[] = ['name' => 'protobuf', 'format' => 'protobuf', 'version' => '', 'decode' => function (string $b, $schema = '') {
            return decodeProtobuf($b, (string) $schema);
        }];
    }
    return $out;
}

function decodeProtobuf(string $data, string $schema): array
{
    if ($schema === 'json') {
        return protobufDocFromJson($data);
    }
    return protobufDocFromWire($data);
}

function protobufDocFromWire(string $data): array
{
    $n = 0;
    $s = '';
    $ok = false;
    $tags = [];
    $i = 0;
    $len = strlen($data);
    while ($i < $len) {
        $key = protobufReadVarint($data, $i, $len);
        $field = $key >> 3;
        $wt = $key & 7;
        if ($wt === 0) {
            $v = protobufReadVarint($data, $i, $len);
            if ($field === 1) {
                $n = protobufZigzag32($v);
            } elseif ($field === 3) {
                $ok = $v !== 0;
            } elseif ($field === 4) {
                $tags[] = protobufZigzag32($v);
            }
        } elseif ($wt === 1) {
            if ($i + 8 > $len) {
                throw new RuntimeException('truncated fixed64');
            }
            $i += 8;
        } elseif ($wt === 5) {
            if ($i + 4 > $len) {
                throw new RuntimeException('truncated fixed32');
            }
            $i += 4;
        } elseif ($wt === 2) {
            $nlen = protobufReadVarint($data, $i, $len);
            if ($i + $nlen > $len) {
                throw new RuntimeException('truncated length-delimited');
            }
            $payload = substr($data, $i, $nlen);
            $i += $nlen;
            if ($field === 2) {
                $s = $payload;
            } elseif ($field === 4) {
                $j = 0;
                $plen = strlen($payload);
                while ($j < $plen) {
                    $tags[] = protobufZigzag32(protobufReadVarint($payload, $j, $plen));
                }
            }
        } else {
            throw new RuntimeException('invalid wire type ' . $wt);
        }
    }
    return ['n' => $n, 's' => $s, 'ok' => $ok, 'tags' => $tags];
}

function protobufReadVarint(string $data, int &$i, int $len): int
{
    $result = 0;
    $shift = 0;
    while ($i < $len) {
        $b = ord($data[$i]);
        $i++;
        $result |= ($b & 0x7f) << $shift;
        if (($b & 0x80) === 0) {
            return $result;
        }
        $shift += 7;
        if ($shift > 63) {
            throw new RuntimeException('varint too long');
        }
    }
    throw new RuntimeException('truncated varint');
}

function protobufZigzag32(int $v): int
{
    // catalog int32 fields are not zigzag; they are plain varint int32
    if ($v > 0x7fffffff) {
        return $v - 0x100000000;
    }
    return $v;
}

function protobufDocFromJson(string $data): array
{
    $probe = json_decode($data, false, 512, JSON_THROW_ON_ERROR);
    if (!is_object($probe)) {
        throw new RuntimeException('proto3 JSON message must be an object');
    }
    $v = json_decode($data, true, 512, JSON_THROW_ON_ERROR);
    if (!is_array($v)) {
        throw new RuntimeException('proto3 JSON message must be an object');
    }
    $n = 0;
    $s = '';
    $ok = false;
    $tags = [];
    if (array_key_exists('n', $v) && $v['n'] !== null) {
        $n = protobufJsonInt32($v['n']);
    }
    if (array_key_exists('s', $v) && $v['s'] !== null) {
        if (!is_string($v['s'])) {
            throw new RuntimeException('s must be a string');
        }
        $s = $v['s'];
    }
    if (array_key_exists('ok', $v) && $v['ok'] !== null) {
        if (!is_bool($v['ok'])) {
            throw new RuntimeException('ok must be a bool');
        }
        $ok = $v['ok'];
    }
    if (array_key_exists('tags', $v) && $v['tags'] !== null) {
        if (!is_array($v['tags'])) {
            throw new RuntimeException('tags must be an array');
        }
        foreach ($v['tags'] as $t) {
            $tags[] = protobufJsonInt32($t);
        }
    }
    return ['n' => $n, 's' => $s, 'ok' => $ok, 'tags' => $tags];
}

function protobufJsonInt32(mixed $v): int
{
    if (is_int($v)) {
        return $v;
    }
    if (is_string($v) && is_numeric($v) && preg_match('/^-?\d+$/', $v)) {
        return (int) $v;
    }
    throw new RuntimeException('int32 must be a number or digit string');
}

function runOne(array $suite, array $c, array $a): array
{
    $base = [
        'id' => $c['id'] ?? '',
        'language' => 'php',
        'serializer' => $a['name'],
        'serializer_version' => $a['version'],
        'format' => $suite['format'],
        'standard' => $suite['standard'],
        'standard_url' => $suite['standard_url'] ?? '',
        'version' => $suite['version'],
        'version_key' => $suite['format'] . '.' . $suite['version'],
        'requirement' => $c['requirement'] ?? '',
        'expect' => $c['expect'] ?? '',
        'section' => $c['section'] ?? '',
        'section_title' => $c['section_title'] ?? '',
        'section_url' => $c['section_url'] ?? '',
        'paragraph' => $c['paragraph'] ?? '',
        'title' => $c['title'] ?? '',
        'input' => $c['input'] ?? '',
        'input_encoding' => $c['input_encoding'] ?? 'utf-8',
        'detail' => '',
        'observed' => '',
        'outcome' => 'pass',
    ];
    try {
        $raw = inputBytes($c);
        $got = ($a['decode'])($raw, $c['schema'] ?? '');
        $ok = true;
        $err = '';
    } catch (Throwable $e) {
        $ok = false;
        $err = $e::class . ': ' . $e->getMessage();
        $got = null;
    }
    $expect = $c['expect'] ?? '';
    if ($expect === 'any') {
        $base['observed'] = $ok ? preview($got) : $err;
        return $base;
    }
    if ($expect === 'reject') {
        if (!$ok) {
            $base['observed'] = $err;
            return $base;
        }
        $base['outcome'] = 'fail';
        $base['detail'] = 'parser accepted input the spec requires to be rejected';
        $base['observed'] = 'accepted as ' . preview($got);
        return $base;
    }
    if (!$ok) {
        $base['outcome'] = 'fail';
        $base['detail'] = 'parser rejected input the spec requires to accept';
        $base['observed'] = $err;
        return $base;
    }
    if (array_key_exists('decoded', $c) && !valuesEqual($c['decoded'], $got)) {
        $base['outcome'] = 'fail';
        $base['detail'] = 'decoded value does not match the catalog case';
        $base['observed'] = 'got ' . preview($got) . ', want ' . preview($c['decoded']);
        return $base;
    }
    $base['observed'] = preview($got);
    return $base;
}

function valuesEqual(mixed $expected, mixed $observed): bool
{
    if (is_array($expected) && count($expected) === 1 && array_key_exists('$hex', $expected)) {
        return is_string($observed) && bin2hex($observed) === preg_replace('/\s+/', '', (string) $expected['$hex']);
    }
    if ($expected === null) {
        return $observed === null;
    }
    if (is_bool($expected) || is_bool($observed)) {
        return $expected === $observed;
    }
    if (is_int($expected) || is_float($expected)) {
        return is_numeric($observed) && (float) $expected === (float) $observed;
    }
    if (is_string($expected)) {
        return $expected === $observed;
    }
    if (is_array($expected)) {
        if (!is_array($observed) || count($expected) !== count($observed)) {
            return false;
        }
        foreach ($expected as $k => $v) {
            if (!array_key_exists($k, $observed) || !valuesEqual($v, $observed[$k])) {
                return false;
            }
        }
        return true;
    }
    return $expected === $observed;
}

function preview(mixed $v): string
{
    $s = json_encode($v, JSON_UNESCAPED_UNICODE);
    if ($s === false) {
        $s = (string) $v;
    }
    return strlen($s) > 120 ? substr($s, 0, 117) . '...' : $s;
}

function printSummary(array $results, array $adapterErrs): void
{
    $p = $f = $s = $e = 0;
    $by = [];
    foreach ($results as $r) {
        match ($r['outcome']) {
            'pass' => $p++,
            'fail' => $f++,
            'skip' => $s++,
            default => $e++,
        };
        $k = (string) $r['standard'] . ' (' . (string) $r['version'] . ') × ' . (string) $r['serializer'];
        $by[$k] ??= [0, 0, 0];
        if ($r['outcome'] === 'pass') {
            $by[$k][0]++;
        } elseif ($r['outcome'] === 'fail') {
            $by[$k][1]++;
        } else {
            $by[$k][2]++;
        }
    }
    echo "Serialization compliance (library deviations are catalogued, not a red build)\n";
    echo "  {$p} pass  {$f} fail  {$s} skip  {$e} error  " . count($results) . " total\n";
    if ($adapterErrs) {
        echo "  Adapter errors:\n";
        foreach ($adapterErrs as $a) {
            echo "    - {$a}\n";
        }
    }
    echo "  By suite × adapter:\n";
    ksort($by);
    foreach ($by as $k => $c) {
        echo "    {$k}: {$c[0]} pass, {$c[1]} fail, {$c[2]} skip\n";
    }
}

function writeReport(string $path, array $results, array $adapterErrs): void
{
    $p = $f = $s = $e = 0;
    $fmts = [];
    foreach ($results as $r) {
        match ($r['outcome']) {
            'pass' => $p++,
            'fail' => $f++,
            'skip' => $s++,
            default => $e++,
        };
        $fmts[$r['format']] = true;
    }
    $doc = [
        'schema' => 'gld.dashboard.compliance/1',
        'generated_at' => gmdate('Y-m-d\TH:i:s\Z'),
        'language' => 'php',
        'languages' => ['php'],
        'policy' => 'report-only',
        'scope' => ['formats' => array_keys($fmts)],
        'passed' => $p,
        'failed' => $f,
        'skipped' => $s,
        'errors' => $e,
        'catalog_errors' => [],
        'serializer_errors' => array_values($adapterErrs),
        'results' => $results,
    ];
    $dir = dirname($path);
    if (!is_dir($dir)) {
        mkdir($dir, 0755, true);
    }
    file_put_contents($path, json_encode($doc, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT) . "\n");
}
