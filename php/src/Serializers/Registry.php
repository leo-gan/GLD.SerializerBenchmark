<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

final class Registry
{
    /** @return list<Serializer> */
    public static function select(string $filter): array
    {
        $all = [
            new JsonSer(),
            new NativeSerializeSer(),
            new IgbinarySer(),
            new MsgpackPeclSer(),
            new MsgpackSer(),
            new ProtobufSer(),
            new SymfonyJsonSer(),
            new SymfonyXmlSer(),
            new JmsJsonSer(),
            new CborSer(),
            new AvroSer(),
            new YamlSer(),
            new YamlPeclSer(),
            new SimdjsonSer(),
            new BsonSer(),
        ];
        $all = array_values(array_filter(
            $all,
            static function (Serializer $s): bool {
                if (method_exists($s, 'available')) {
                    return (bool) $s::available();
                }
                return true;
            },
        ));
        $f = strtolower($filter);
        if ($f === '') {
            return $all;
        }
        return array_values(array_filter(
            $all,
            static fn (Serializer $s) => str_contains(strtolower($s->name()), $f),
        ));
    }
}
