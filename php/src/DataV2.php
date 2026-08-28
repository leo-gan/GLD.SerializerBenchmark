<?php

declare(strict_types=1);

namespace Benchmark;

/**
 * Suite v2 fixtures. Deterministic within PHP; not bit-identical across languages.
 * RNG: xorshift64* with golden-ratio mix (same constants as the JS/Python generators).
 */
final class DataV2
{
    private const BASE_TS_MS = 1704067200000;
    private const GOLDEN = 0x9E3779B97F4A7C15;

    public static function makeOne(string $typeId, array $typeConfig, int $seed, int $instanceIndex): mixed
    {
        $rng = new Rng(self::mixSeed($seed, $typeId, $instanceIndex));
        $children = (int) ($typeConfig['children'] ?? 8);
        $points = (int) ($typeConfig['points'] ?? 32);
        $count = (int) ($typeConfig['count'] ?? 32);
        $attrCount = (int) ($typeConfig['attr_count'] ?? 4);

        return match ($typeId) {
            'message' => [
                'f_bool' => $rng->nextBool(),
                'f_int32' => $rng->nextInt(0, 1_000_000),
                'f_int64' => $rng->nextInt(0, 1_000_000),
                'f_float64' => $rng->nextF64() * 1000.0,
                'f_string' => $rng->word(3, 16),
                'f_bool_2' => $rng->nextBool(),
                'f_int32_2' => $rng->nextInt(0, 1_000_000),
                'f_string_2' => $rng->word(3, 16),
            ],
            'document' => self::document($rng, $children),
            'telemetry' => [
                'source' => $rng->word(4, 12),
                'ts' => self::BASE_TS_MS + $rng->nextInt(0, 86_400_000),
                'tags' => [$rng->word(3, 8), $rng->word(3, 8)],
                'values' => array_map(static fn () => $rng->nextF64() * 100.0, range(1, $points)),
            ],
            'strings' => [
                'items' => array_map(static fn () => $rng->word(3, 12), range(1, $count)),
            ],
            'event' => [
                'event_id' => $rng->word(8, 16),
                'event_type' => $rng->word(4, 10),
                'occurred_at' => self::BASE_TS_MS + $rng->nextInt(0, 86_400_000),
                'producer' => $rng->word(4, 12),
                'attrs' => array_map(
                    static fn () => ['key' => $rng->word(3, 8), 'value' => $rng->word(3, 16)],
                    range(1, $attrCount),
                ),
            ],
            default => throw new \InvalidArgumentException($typeId),
        };
    }

    public static function instances(string $typeId, array $typeConfig, int $seed, int $n): array
    {
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[] = self::makeOne($typeId, $typeConfig, $seed, $i);
        }
        return $out;
    }

    private static function document(Rng $rng, int $children): array
    {
        $items = [];
        for ($i = 0; $i < $children; $i++) {
            $items[] = [
                'sku' => $rng->word(3, 12),
                'qty' => $rng->nextInt(1, 100),
                'price_minor' => $rng->nextInt(0, 100_000),
            ];
        }
        return [
            'id' => $rng->word(8, 12),
            'status' => $rng->nextInt(0, 5),
            'meta' => ['region' => $rng->word(2, 4), 'version' => $rng->nextInt(1, 9)],
            'items' => $items,
        ];
    }

    private static function mixSeed(int $seed, string $typeId, int $idx): int
    {
        $h = $seed & 0x7FFFFFFF;
        $len = strlen($typeId);
        for ($i = 0; $i < $len; $i++) {
            $h = (($h ^ ord($typeId[$i])) * 16777619) & 0x7FFFFFFF;
        }
        $h = ($h ^ (($idx * 0x9E3779B9) & 0x7FFFFFFF)) & 0x7FFFFFFF;
        return $h === 0 ? 1 : $h;
    }
}

final class Rng
{
    private int $state;

    public function __construct(int $seed)
    {
        $this->state = $seed === 0 ? 0x7E3779B9 : ($seed & 0x7FFFFFFF);
        if ($this->state === 0) {
            $this->state = 1;
        }
    }

    public function nextU31(): int
    {
        $x = $this->state;
        $x ^= ($x << 13) & 0x7FFFFFFF;
        $x ^= $x >> 7;
        $x ^= ($x << 17) & 0x7FFFFFFF;
        $this->state = $x & 0x7FFFFFFF;
        return $this->state;
    }

    public function nextInt(int $lo, int $hi): int
    {
        if ($hi <= $lo) {
            return $lo;
        }
        return $lo + (int) ($this->nextU31() % ($hi - $lo + 1));
    }

    public function nextBool(): bool
    {
        return ($this->nextU31() & 1) === 1;
    }

    public function nextF64(): float
    {
        return $this->nextU31() / 2147483647.0;
    }

    public function word(int $minL, int $maxL): string
    {
        $n = $this->nextInt($minL, $maxL);
        $s = '';
        for ($i = 0; $i < $n; $i++) {
            $s .= chr(ord('a') + (int) ($this->nextU31() % 26));
        }
        return $s;
    }
}
