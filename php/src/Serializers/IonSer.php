<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Benchmark\ProtoBridge;
use function Gld\Ion\decode_value;
use function Gld\Ion\encode_value;

/** Ion 1.0 binary document for a suite value. Skips graph. */
final class IonSer extends BytesSer
{
    private string $kind = '';

    public function name(): string
    {
        return 'gld-ion';
    }

    public function version(): string
    {
        return '0.2.0';
    }

    public function streamMode(): string
    {
        return 'adapted';
    }

    public function prepare(mixed $value): void
    {
        self::rejectGraph($value);
        [$this->kind] = ProtoBridge::detect($value);
    }

    public function serializeBytes(mixed $value): string
    {
        if ($this->kind === '') {
            throw new \InvalidArgumentException('gld-ion');
        }
        return encode_value($value);
    }

    public function deserializeBytes(string $data): mixed
    {
        return decode_value($data);
    }

    private static function rejectGraph(mixed $value): void
    {
        $row = is_array($value) && array_is_list($value) ? ($value[0] ?? null) : $value;
        if (is_array($row) && array_key_exists('orders', $row) && array_key_exists('people', $row)) {
            throw new \InvalidArgumentException('graph');
        }
    }
}
