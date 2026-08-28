<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Symfony\Component\Serializer\Encoder\XmlEncoder;
use Symfony\Component\Serializer\Normalizer\ArrayDenormalizer;
use Symfony\Component\Serializer\Normalizer\ObjectNormalizer;
use Symfony\Component\Serializer\Serializer as SfSerializer;

final class SymfonyXmlSer extends BytesSer
{
    private SfSerializer $sf;

    public function __construct()
    {
        $this->sf = new SfSerializer(
            [new ObjectNormalizer(), new ArrayDenormalizer()],
            [new XmlEncoder()],
        );
    }

    public function name(): string
    {
        return 'symfony-xml';
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
        $payload = is_array($value) && array_is_list($value) ? ['batch' => $value] : $value;
        return $this->sf->encode($payload, 'xml');
    }

    public function deserializeBytes(string $data): mixed
    {
        $php = $this->sf->decode($data, 'xml');
        if (is_array($php) && array_key_exists('batch', $php)) {
            $batch = $php['batch'];
            return is_array($batch) ? array_values($batch) : $batch;
        }
        return $php;
    }
}
