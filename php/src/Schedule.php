<?php

declare(strict_types=1);

namespace Benchmark;

final class Schedule
{
    public static function strategy(): string
    {
        $env = strtolower(trim((string) (getenv('BENCHMARK_SCHEDULE') ?: '')));
        return $env === 'none' ? 'none' : 'block_shuffle';
    }

    public static function recordRunOrder(): bool
    {
        $env = strtolower(trim((string) (getenv('BENCHMARK_RECORD_RUN_ORDER') ?: '1')));
        return $env !== '0' && $env !== 'false';
    }

    /** @param list<string> $names */
    public static function shuffle(array $names, int $seed, string $typeId, int $n, string $hash, string $mode, int $rep): array
    {
        $h = $seed;
        $h = self::mix($h, $typeId);
        $h = self::mix($h, (string) $n);
        $h = self::mix($h, $hash);
        $h = self::mix($h, $mode);
        $h = self::mix($h, (string) $rep);
        $rng = $h === 0 ? 1 : ($h & 0x7FFFFFFF);
        $out = $names;
        $count = count($out);
        for ($i = $count - 1; $i > 0; $i--) {
            $rng = ($rng * 1103515245 + 12345) & 0x7FFFFFFF;
            $j = $rng % ($i + 1);
            [$out[$i], $out[$j]] = [$out[$j], $out[$i]];
        }
        return $out;
    }

    private static function mix(int $h, string $s): int
    {
        $len = strlen($s);
        for ($i = 0; $i < $len; $i++) {
            $h = (($h ^ ord($s[$i])) * 16777619) & 0x7FFFFFFF;
        }
        return $h;
    }
}
