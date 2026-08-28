<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

abstract class BytesSer implements Serializer
{
    public function serializeStream(mixed $value, $out): int
    {
        $bytes = $this->serializeBytes($value);
        fwrite($out, $bytes);
        return strlen($bytes);
    }

    public function deserializeStream($in): mixed
    {
        $data = stream_get_contents($in);
        if ($data === false) {
            throw new \RuntimeException($this->name() . ' stream read failed');
        }
        return $this->deserializeBytes($data);
    }
}
