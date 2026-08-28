<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use MessagePack\BufferUnpacker;
use MessagePack\Packer;

final class MsgpackSer implements Serializer
{
    private Packer $packer;
    private BufferUnpacker $unpacker;

    public function __construct()
    {
        $this->packer = new Packer();
        $this->unpacker = new BufferUnpacker();
    }

    public function name(): string
    {
        return 'rybakit-msgpack';
    }

    public function version(): string
    {
        return \Composer\InstalledVersions::getPrettyVersion('rybakit/msgpack') ?? 'rybakit/msgpack';
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
        return $this->packer->pack($value);
    }

    public function deserializeBytes(string $data): mixed
    {
        $this->unpacker->reset($data);
        return $this->unpacker->unpack();
    }

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
            throw new \RuntimeException('msgpack stream read failed');
        }
        return $this->deserializeBytes($data);
    }
}
