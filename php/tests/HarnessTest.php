<?php

declare(strict_types=1);

/**
 * Minimal harness checks (no PHPUnit required).
 *   php php/tests/HarnessTest.php
 */
require dirname(__DIR__) . '/vendor/autoload.php';

use Benchmark\DataV2;
use Benchmark\Serializers\ArrowSer;
use Benchmark\Serializers\IonSer;
use Benchmark\Serializers\JsonSer;
use Benchmark\Serializers\Registry;

$fail = 0;
function check(string $name, bool $ok, string $detail = ''): void
{
    global $fail;
    if ($ok) {
        echo "OK  $name\n";
    } else {
        echo "FAIL  $name" . ($detail !== '' ? " — $detail" : '') . "\n";
        $fail++;
    }
}

$a = DataV2::makeOne('document', [], 42, 0);
$b = DataV2::makeOne('document', [], 42, 0);
check('document seed is deterministic', $a === $b);

$c = DataV2::makeOne('document', [], 42, 1);
check('instance index changes the value', $a !== $c);

$batch = DataV2::instances('message', [], 42, 3);
check('instances() length', count($batch) === 3);

$json = new JsonSer();
$json->prepare($a);
$bytes = $json->serializeBytes($a);
$back = $json->deserializeBytes($bytes);
check('json document round-trip', $back['id'] === $a['id'] && count($back['items']) === count($a['items']));
check('json size is not empty', strlen($bytes) > 10);

$names = array_map(static fn ($s) => $s->name(), Registry::select(''));
check('registry includes json', in_array('json', $names, true));
check('registry includes protobuf', in_array('protobuf', $names, true));
check('registry includes serialize', in_array('serialize', $names, true));
check('registry includes gld-arrow', in_array('gld-arrow', $names, true));
check('registry includes gld-ion', in_array('gld-ion', $names, true));

foreach ([new ArrowSer(), new IonSer()] as $ser) {
    check($ser->name() . ' version', $ser->version() === '0.2.0');
    check($ser->name() . ' stream mode', $ser->streamMode() === 'adapted');
    $skipped = false;
    try {
        $ser->prepare(['orders' => [], 'people' => []]);
    } catch (\InvalidArgumentException) {
        $skipped = true;
    }
    check($ser->name() . ' skips graph', $skipped);

    $msg = DataV2::makeOne('message', [], 42, 0);
    $ser->prepare($msg);
    $bytes = $ser->serializeBytes($msg);
    $back = $ser->deserializeBytes($bytes);
    check($ser->name() . ' message round-trip', sameValue($msg, $back), $ser->name());
    check($ser->name() . ' message size', strlen($bytes) > 8);

    foreach (['document', 'telemetry', 'strings', 'event'] as $typeId) {
        $one = DataV2::makeOne($typeId, [], 42, 0);
        $ser->prepare($one);
        $raw = $ser->serializeBytes($one);
        check($ser->name() . " $typeId round-trip", sameValue($one, $ser->deserializeBytes($raw)));
    }

    $batch = DataV2::instances('message', [], 42, 3);
    $ser->prepare($batch);
    check($ser->name() . ' message batch', sameValue($batch, $ser->deserializeBytes($ser->serializeBytes($batch))));
}

exit($fail === 0 ? 0 : 1);

function sameValue(mixed $a, mixed $b): bool
{
    if (is_array($a) && is_array($b)) {
        if (count($a) !== count($b)) {
            return false;
        }
        foreach ($a as $k => $x) {
            if (!array_key_exists($k, $b) || !sameValue($x, $b[$k])) {
                return false;
            }
        }
        return true;
    }
    if (is_bool($a) || is_bool($b)) {
        return $a === $b;
    }
    if (is_int($a) && is_int($b)) {
        return $a === $b;
    }
    if (is_float($a) || is_float($b)) {
        return abs((float) $a - (float) $b) < 1e-8;
    }
    return $a === $b;
}
