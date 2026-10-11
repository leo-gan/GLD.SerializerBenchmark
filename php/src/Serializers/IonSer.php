<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Benchmark\ProtoBridge;
use Gld\Ion\Catalog;
use Gld\Ion\EncodeOptions;
use Gld\Ion\FloatBits;
use Gld\Ion\IonDoc;
use Gld\Ion\Kind;
use function Gld\Ion\decode;
use function Gld\Ion\encode;

/** Ion 1.0 binary document for a suite value. Skips graph. */
final class IonSer extends BytesSer
{
    private string $kind = '';
    private EncodeOptions $options;
    private Catalog $catalog;

    public function __construct()
    {
        $this->options = new EncodeOptions(true, false, 10);
        $this->catalog = new Catalog();
    }

    public function name(): string
    {
        return 'gld-ion';
    }

    public function version(): string
    {
        return '0.2.0';
    }

    public function streamMode(): string
    {
        return 'adapted';
    }

    public function prepare(mixed $value): void
    {
        self::rejectGraph($value);
        [$this->kind] = ProtoBridge::detect($value);
        $this->options = new EncodeOptions(true, false, 10);
        $this->catalog = new Catalog();
    }

    public function serializeBytes(mixed $value): string
    {
        if ($this->kind === '') {
            throw new \InvalidArgumentException('gld-ion');
        }
        $doc = new IonDoc();
        $doc->add_top(self::put($doc, $value));
        return encode($doc, $this->options, $this->catalog);
    }

    public function deserializeBytes(string $data): mixed
    {
        $doc = decode($data, $this->catalog);
        if (count($doc->top) !== 1) {
            throw new \RuntimeException('gld-ion: expected one value');
        }
        return self::get($doc, $doc->top[0]);
    }

    private static function rejectGraph(mixed $value): void
    {
        $row = is_array($value) && array_is_list($value) ? ($value[0] ?? null) : $value;
        if (is_array($row) && array_key_exists('orders', $row) && array_key_exists('people', $row)) {
            throw new \InvalidArgumentException('graph');
        }
    }

    private static function put(IonDoc $doc, mixed $v): int
    {
        if (is_bool($v)) {
            return $doc->add_bool($v);
        }
        if (is_int($v)) {
            return $doc->add_i64($v);
        }
        if (is_float($v)) {
            return $doc->add_float(8, FloatBits::f64($v));
        }
        if (is_string($v)) {
            return $doc->add_string($v);
        }
        if (!is_array($v)) {
            throw new \InvalidArgumentException('gld-ion value');
        }
        if (array_is_list($v)) {
            $list = $doc->start_container(Kind::LIST);
            foreach ($v as $item) {
                $doc->add_child($list, self::put($doc, $item), -1);
            }
            return $list;
        }
        $st = $doc->start_container(Kind::STRUCT);
        foreach ($v as $k => $item) {
            $sym = $doc->add_symbol_text((string) $k);
            $doc->add_child($st, self::put($doc, $item), $doc->nodes[$sym]->a);
        }
        return $st;
    }

    private static function get(IonDoc $doc, int $id): mixed
    {
        $kind = $doc->nodes[$id]->kind;
        return match ($kind) {
            Kind::BOOL => $doc->as_bool($id),
            Kind::INT => $doc->as_i64($id),
            Kind::FLOAT => $doc->as_f64($id),
            Kind::STRING => $doc->as_string($id),
            Kind::LIST => self::getList($doc, $id),
            Kind::STRUCT => self::getStruct($doc, $id),
            default => throw new \RuntimeException('gld-ion kind ' . $kind),
        };
    }

    /** @return list<mixed> */
    private static function getList(IonDoc $doc, int $id): array
    {
        $n = $doc->nodes[$id]->nchild;
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[] = self::get($doc, $doc->child_at($id, $i));
        }
        return $out;
    }

    /** @return array<string,mixed> */
    private static function getStruct(IonDoc $doc, int $id): array
    {
        $n = $doc->nodes[$id]->nchild;
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[$doc->field_name($id, $i)] = self::get($doc, $doc->child_at($id, $i));
        }
        return $out;
    }
}
