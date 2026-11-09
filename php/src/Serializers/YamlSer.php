<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Symfony\Component\Yaml\Yaml;

final class YamlSer extends BytesSer
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

    public function serializeBytes(mixed $value): string
    {
        return Yaml::dump($value, 8, 2);
    }

    public function deserializeBytes(string $data): mixed
    {
        return Yaml::parse($data);
    }
}
