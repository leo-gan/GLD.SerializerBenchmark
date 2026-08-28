<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Symfony\Component\Yaml\Yaml;

final class YamlSer implements Serializer
{
    public function name(): string
    {
        return 'yaml';
    }

    public function version(): string
    {
        return \Composer\InstalledVersions::getPrettyVersion('symfony/yaml') ?? 'symfony/yaml';
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
        return Yaml::dump($value, 8, 2);
    }

    public function deserializeBytes(string $data): mixed
    {
        return Yaml::parse($data);
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
            throw new \RuntimeException('yaml stream read failed');
        }
        return $this->deserializeBytes($data);
    }
}
