<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

interface Serializer
{
    public function name(): string;

    public function version(): string;

    /** native | adapted | text_on_stream */
    public function streamMode(): string;

    public function prepare(mixed $value): void;

    public function serializeBytes(mixed $value): string;

    public function deserializeBytes(string $data): mixed;

    public function serializeStream(mixed $value, $out): int;

    public function deserializeStream($in): mixed;
}
