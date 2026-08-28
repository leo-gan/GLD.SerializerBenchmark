<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use JMS\Serializer\SerializerBuilder;
use JMS\Serializer\SerializerInterface;

final class JmsJsonSer extends BytesSer
{
    private SerializerInterface $jms;

    public function __construct()
    {
        $this->jms = SerializerBuilder::create()->build();
    }

    public function name(): string
    {
        return 'jms-json';
    }

    public function version(): string
    {
        return \Composer\InstalledVersions::getPrettyVersion('jms/serializer') ?? 'jms/serializer';
    }

    public function streamMode(): string
    {
        return 'text_on_stream';
    }

    public function prepare(mixed $value): void
    {
    }

    public function serializeBytes(mixed $value): string
    {
        return $this->jms->serialize($value, 'json');
    }

    public function deserializeBytes(string $data): mixed
    {
        return $this->jms->deserialize($data, 'array', 'json');
    }
}
