<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

final class BsonSer extends BytesSer
{
    public static function available(): bool
    {
        return class_exists(\MongoDB\BSON\Document::class);
    }

    public function name(): string
    {
        return 'bson';
    }

    public function version(): string
    {
        return phpversion('mongodb') ?: 'ext-mongodb';
    }

    public function streamMode(): string
    {
        return 'adapted';
    }

    public function prepare(mixed $value): void
    {
    }

    public function serializeBytes(mixed $value): string
    {
        $root = is_array($value) && array_is_list($value) ? ['batch' => $value] : $value;
        return (string) \MongoDB\BSON\Document::fromPHP((object) $root);
    }

    public function deserializeBytes(string $data): mixed
    {
        $php = \MongoDB\BSON\Document::fromBSON($data)->toPHP([
            'root' => 'array',
            'document' => 'array',
            'array' => 'array',
        ]);
        if (is_array($php) && array_key_exists('batch', $php)) {
            return $php['batch'];
        }
        return $php;
    }
}
