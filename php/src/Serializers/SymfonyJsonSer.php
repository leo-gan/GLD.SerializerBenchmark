<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Symfony\Component\Serializer\Encoder\JsonEncoder;
use Symfony\Component\Serializer\Normalizer\ArrayDenormalizer;
use Symfony\Component\Serializer\Normalizer\ObjectNormalizer;
use Symfony\Component\Serializer\Serializer as SfSerializer;

final class SymfonyJsonSer extends BytesSer
{
    private SfSerializer $sf;

    public function __construct()
    {
        $this->sf = new SfSerializer(
            [new ObjectNormalizer(), new ArrayDenormalizer()],
            [new JsonEncoder()],
        );
    }

    public function name(): string
    {
        return 'symfony-json';
    }

    public function version(): string
    {
        return \Composer\InstalledVersions::getPrettyVersion('symfony/serializer') ?? 'symfony/serializer';
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
        return $this->sf->encode($value, 'json');
    }

    public function deserializeBytes(string $data): mixed
    {
        return $this->sf->decode($data, 'json');
    }
}
