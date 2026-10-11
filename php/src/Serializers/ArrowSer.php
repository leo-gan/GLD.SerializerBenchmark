<?php

declare(strict_types=1);

namespace Benchmark\Serializers;

use Benchmark\ProtoBridge;
use Gld\Arrow\Arrow;
use Gld\Arrow\Runtime\Bin;
use Gld\Arrow\Runtime\Field;
use Gld\Arrow\Runtime\Layout;
use Gld\Arrow\Runtime\TableBuilder;
use Gld\Arrow\Runtime\Type;
use Gld\Arrow\Runtime\Values;

/** One Arrow IPC stream for a suite record or a batch of records. Skips graph. */
final class ArrowSer extends BytesSer
{
    private string $kind = '';
    private bool $batch = false;

    public function name(): string
    {
        return 'gld-arrow';
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
        [$this->kind, $this->batch] = ProtoBridge::detect($value);
    }

    public function serializeBytes(mixed $value): string
    {
        $rows = $this->batch ? $value : [$value];
        if (!is_array($rows)) {
            throw new \InvalidArgumentException($this->kind);
        }
        $b = new TableBuilder();
        match ($this->kind) {
            'message' => self::message($b, $rows),
            'document' => self::document($b, $rows),
            'telemetry' => self::telemetry($b, $rows),
            'strings' => self::strings($b, $rows),
            'event' => self::event($b, $rows),
            default => throw new \InvalidArgumentException($this->kind),
        };
        return Arrow::writeStream($b->build());
    }

    public function deserializeBytes(string $data): mixed
    {
        $col = Arrow::readStream($data);
        if ($col->batches === []) {
            throw new \RuntimeException('gld-arrow: no record batch');
        }
        $batch = $col->batches[0];
        $columns = [];
        foreach ($batch->cols as $aid) {
            $field = $col->fields[$col->arrays[$aid]->field];
            $columns[$field->name] = Values::column($col, $aid);
        }
        $rows = [];
        for ($i = 0; $i < $batch->length; $i++) {
            $row = [];
            foreach ($columns as $name => $values) {
                $row[$name] = self::normalize($values[$i]);
            }
            $rows[] = $row;
        }
        if ($rows === []) {
            throw new \RuntimeException('gld-arrow: empty batch');
        }
        return $this->batch ? $rows : $rows[0];
    }

    private static function rejectGraph(mixed $value): void
    {
        $row = is_array($value) && array_is_list($value) ? ($value[0] ?? null) : $value;
        if (is_array($row) && array_key_exists('orders', $row) && array_key_exists('people', $row)) {
            throw new \InvalidArgumentException('graph');
        }
    }

    /** @param list<array<string,mixed>> $rows */
    private static function message(TableBuilder $b, array $rows): void
    {
        $b->bools('f_bool', self::col($rows, 'f_bool'), false);
        $b->int32('f_int32', self::col($rows, 'f_int32'), false);
        $b->int64('f_int64', self::col($rows, 'f_int64'), false);
        $b->float64('f_float64', self::col($rows, 'f_float64'), false);
        $b->utf8('f_string', self::col($rows, 'f_string'), false);
        $b->bools('f_bool_2', self::col($rows, 'f_bool_2'), false);
        $b->int32('f_int32_2', self::col($rows, 'f_int32_2'), false);
        $b->utf8('f_string_2', self::col($rows, 'f_string_2'), false);
    }

    /** @param list<array<string,mixed>> $rows */
    private static function document(TableBuilder $b, array $rows): void
    {
        $b->utf8('id', self::col($rows, 'id'), false);
        $b->int32('status', self::col($rows, 'status'), false);
        [, $meta] = self::structArray($b, 'meta', self::col($rows, 'meta'), [
            ['name' => 'region', 'kind' => 'utf8'],
            ['name' => 'version', 'kind' => 'int32'],
        ], false);
        $b->column($meta);
        self::listStruct($b, 'items', self::col($rows, 'items'), [
            ['name' => 'sku', 'kind' => 'utf8'],
            ['name' => 'qty', 'kind' => 'int32'],
            ['name' => 'price_minor', 'kind' => 'int64'],
        ]);
    }

    /** @param list<array<string,mixed>> $rows */
    private static function telemetry(TableBuilder $b, array $rows): void
    {
        $b->utf8('source', self::col($rows, 'source'), false);
        $b->int64('ts', self::col($rows, 'ts'), false);
        self::listPrimitive($b, 'tags', self::col($rows, 'tags'), 'utf8');
        self::listPrimitive($b, 'values', self::col($rows, 'values'), 'float64');
    }

    /** @param list<array<string,mixed>> $rows */
    private static function strings(TableBuilder $b, array $rows): void
    {
        self::listPrimitive($b, 'items', self::col($rows, 'items'), 'utf8');
    }

    /** @param list<array<string,mixed>> $rows */
    private static function event(TableBuilder $b, array $rows): void
    {
        $b->utf8('event_id', self::col($rows, 'event_id'), false);
        $b->utf8('event_type', self::col($rows, 'event_type'), false);
        $b->int64('occurred_at', self::col($rows, 'occurred_at'), false);
        $b->utf8('producer', self::col($rows, 'producer'), false);
        self::listStruct($b, 'attrs', self::col($rows, 'attrs'), [
            ['name' => 'key', 'kind' => 'utf8'],
            ['name' => 'value', 'kind' => 'utf8'],
        ]);
    }

    /** @param list<array<string,mixed>> $rows @return list<mixed> */
    private static function col(array $rows, string $key): array
    {
        $out = [];
        foreach ($rows as $row) {
            $out[] = $row[$key];
        }
        return $out;
    }

    /**
     * @param list<list<mixed>> $rows
     */
    private static function listPrimitive(TableBuilder $b, string $name, array $rows, string $kind): void
    {
        $flat = [];
        foreach ($rows as $row) {
            foreach ($row as $v) {
                $flat[] = $v;
            }
        }
        [$fid, $aid] = match ($kind) {
            'utf8' => self::utf8Array($b, 'item', $flat, false),
            'float64' => self::float64Array($b, 'item', $flat, false),
            'int32' => self::intArray($b, 'item', $flat, 32, false),
            'int64' => self::intArray($b, 'item', $flat, 64, false),
            default => throw new \InvalidArgumentException($kind),
        };
        self::finishList($b, $name, $fid, $aid, $rows);
    }

    /**
     * @param list<list<array<string,mixed>>> $rows
     * @param list<array{name:string,kind:string}> $spec
     */
    private static function listStruct(TableBuilder $b, string $name, array $rows, array $spec): void
    {
        $flat = [];
        foreach ($rows as $row) {
            foreach ($row as $item) {
                $flat[] = $item;
            }
        }
        [$fid, $aid] = self::structArray($b, 'item', $flat, $spec, false);
        self::finishList($b, $name, $fid, $aid, $rows);
    }

    /**
     * @param list<array<string,mixed>> $rows
     * @param list<array{name:string,kind:string}> $spec
     * @return array{0:int,1:int}
     */
    private static function structArray(TableBuilder $b, string $name, array $rows, array $spec, bool $nullable): array
    {
        $childFields = [];
        $childArrays = [];
        foreach ($spec as $col) {
            $vals = [];
            foreach ($rows as $row) {
                $vals[] = $row[$col['name']];
            }
            [$fid, $aid] = match ($col['kind']) {
                'utf8' => self::utf8Array($b, $col['name'], $vals, false),
                'int32' => self::intArray($b, $col['name'], $vals, 32, false),
                'int64' => self::intArray($b, $col['name'], $vals, 64, false),
                'float64' => self::float64Array($b, $col['name'], $vals, false),
                default => throw new \InvalidArgumentException($col['kind']),
            };
            $childFields[] = $fid;
            $childArrays[] = $aid;
        }
        $fid = $b->addField(Field::nested($name, Type::T_STRUCT, $childFields, $nullable));
        $aid = $b->addArray($fid, count($rows), 0, [''], $childArrays);
        return [$fid, $aid];
    }

    /** @param list<array<mixed>> $rows */
    private static function finishList(TableBuilder $b, string $name, int $childField, int $childArray, array $rows): void
    {
        $offs = pack('V', 0);
        $cursor = 0;
        foreach ($rows as $row) {
            $cursor += count($row);
            $offs .= pack('V', $cursor);
        }
        $fid = $b->addField(Field::nested($name, Type::T_LIST, [$childField], false));
        $aid = $b->addArray($fid, count($rows), 0, ['', $offs], [$childArray]);
        $b->column($aid);
    }

    /** @param list<string> $values @return array{0:int,1:int} */
    private static function utf8Array(TableBuilder $b, string $name, array $values, bool $nullable): array
    {
        $data = '';
        $offs = pack('V', 0);
        $cursor = 0;
        foreach ($values as $v) {
            Bin::utf8($v);
            $data .= $v;
            $cursor += strlen($v);
            $offs .= pack('V', $cursor);
        }
        $fid = $b->addField(Field::utf8($name, $nullable));
        $aid = $b->addArray($fid, count($values), 0, ['', $offs, $data]);
        return [$fid, $aid];
    }

    /** @param list<int> $values @return array{0:int,1:int} */
    private static function intArray(TableBuilder $b, string $name, array $values, int $width, bool $nullable): array
    {
        $fid = $b->addField(Field::int($name, $width, true, $nullable));
        $aid = $b->addArray($fid, count($values), 0, ['', Layout::packInts($values, intdiv($width, 8))]);
        return [$fid, $aid];
    }

    /** @param list<float> $values @return array{0:int,1:int} */
    private static function float64Array(TableBuilder $b, string $name, array $values, bool $nullable): array
    {
        $raw = '';
        foreach ($values as $v) {
            $raw .= pack('e', $v);
        }
        $f = Field::named($name, Type::T_FLOAT, $nullable);
        $f->unit = 2;
        $fid = $b->addField($f);
        $aid = $b->addArray($fid, count($values), 0, ['', $raw]);
        return [$fid, $aid];
    }

    private static function normalize(mixed $v): mixed
    {
        if (!is_array($v)) {
            return $v;
        }
        $list = true;
        foreach ($v as $k => $_) {
            if (!is_int($k)) {
                $list = false;
                break;
            }
        }
        if ($list) {
            $out = [];
            foreach ($v as $item) {
                $out[] = self::normalize($item);
            }
            return $out;
        }
        $out = [];
        foreach ($v as $k => $item) {
            $out[$k] = self::normalize($item);
        }
        return $out;
    }
}
