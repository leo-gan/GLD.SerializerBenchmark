<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use HelgeSverre\Toon\DecodeOptions;
use HelgeSverre\Toon\EncodeOptions;
use HelgeSverre\Toon\SpecVersion;
use HelgeSverre\Toon\Toon;

/**
 * helgesverre/toon. The package default wire version is 3.3. This row
 * selects 4.4, the current specification. Encode returns a string, so the
 * stream path writes those UTF-8 bytes. Size is that byte length.
 * https://github.com/HelgeSverre/toon-php
 */
final class ToonSer extends BytesSer
{
    private EncodeOptions $encode;

    private DecodeOptions $decode;

    public function __construct()
    {
        $this->encode = new EncodeOptions(version: SpecVersion::V4_4);
        $this->decode = new DecodeOptions(version: SpecVersion::V4_4);
    }

    public function name(): string
    {
        return 'toon';
    }

    public function version(): string
    {
        return \Composer\InstalledVersions::getPrettyVersion('helgesverre/toon') ?? 'helgesverre/toon';
    }

    public function streamMode(): string
    {
        return 'adapted';
    }

    public function serializeBytes(mixed $value): string
    {
        return Toon::encode($value, $this->encode);
    }

    public function deserializeBytes(string $data): mixed
    {
        return Toon::decode($data, $this->decode);
    }
}
