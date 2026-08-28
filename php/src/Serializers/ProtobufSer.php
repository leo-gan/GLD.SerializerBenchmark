<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Benchmark\ProtoBridge;
use Google\Protobuf\Internal\Message;

final class ProtobufSer extends BytesSer
{
    private mixed $sample = null;

    public function name(): string
    {
        return 'protobuf';
    }

    public function version(): string
    {
        $pkg = \Composer\InstalledVersions::getPrettyVersion('google/protobuf') ?? 'google/protobuf';
        return extension_loaded('protobuf') ? $pkg . '+ext' : $pkg . '+php';
    }

    public function streamMode(): string
    {
        return 'adapted';
    }

    public function prepare(mixed $value): void
    {
        \GPBMetadata\BenchmarkV2::initOnce();
        $this->sample = $value;
    }

    public function serializeBytes(mixed $value): string
    {
        return ProtoBridge::toProto($value)->serializeToString();
    }

    public function deserializeBytes(string $data): mixed
    {
        $msg = ProtoBridge::emptyMessage($this->sample);
        $msg->mergeFromString($data);
        return ProtoBridge::fromProto($msg);
    }
}
