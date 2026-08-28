<?php

declare(strict_types=1);

/**
 * Minimal harness checks (no PHPUnit required).
 *   php php/tests/HarnessTest.php
 */
require dirname(__DIR__) . '/vendor/autoload.php';

use Benchmark\DataV2;
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

exit($fail === 0 ? 0 : 1);
