<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use CBOR\ByteStringObject;
use CBOR\Decoder;
use CBOR\Encoder;
use CBOR\StringStream;
use CBOR\Tag\UnsignedBigIntegerTag;

final class CborSer extends BytesSer
{
    private Encoder $encoder;
    private Decoder $decoder;

    public function __construct()
    {
        $this->encoder = new Encoder();
        $this->decoder = Decoder::create();
    }

    public function name(): string
    {
        return 'cbor';
    }

    public function version(): string
    {
        return \Composer\InstalledVersions::getPrettyVersion('spomky-labs/cbor-php') ?? 'spomky-labs/cbor-php';
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
        return $this->encoder->encode(self::wrapLargeInts($value));
    }

    public function deserializeBytes(string $data): mixed
    {
        $obj = $this->decoder->decode(StringStream::create($data));
        return self::toPhp($obj->normalize());
    }

    /** Encoder only accepts 32-bit unsigned ints; tag larger values (RFC 8949 bignums). */
    private static function wrapLargeInts(mixed $v): mixed
    {
        if (is_int($v) && $v > 0xFFFFFFFF) {
            $hex = dechex($v);
            if ((strlen($hex) % 2) === 1) {
                $hex = '0' . $hex;
            }
            return UnsignedBigIntegerTag::create(ByteStringObject::create((string) hex2bin($hex)));
        }
        if (is_array($v)) {
            $out = [];
            foreach ($v as $k => $x) {
                $out[$k] = self::wrapLargeInts($x);
            }
            return $out;
        }
        return $v;
    }

    /** CBOR normalize() often yields numeric strings for integers. */
    private static function toPhp(mixed $v): mixed
    {
        if (is_array($v)) {
            $out = [];
            foreach ($v as $k => $x) {
                $out[$k] = self::toPhp($x);
            }
            return $out;
        }
        if (is_string($v) && is_numeric($v)) {
            if (str_contains($v, '.') || str_contains(strtolower($v), 'e')) {
                return (float) $v;
            }
            if (strlen($v) < 16 || (strlen($v) === 16 && $v[0] !== '9')) {
                return (int) $v;
            }
        }
        return $v;
    }
}
