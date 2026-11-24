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
use Gld\Arrow\Wire\StreamTemplate;

/** One Arrow IPC stream for a suite record or a batch of records. Skips graph. */
final class ArrowSer extends BytesSer
{
    private string $kind = '';
    private bool $batch = false;
    private ?StreamTemplate $template = null;
    private int $nrows = 0;

    /** Utf8 data buffers omitted because the prepared fixture's bytes were empty. */
    private array $omit = [];

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
        $rows = $this->rowsOf($value);
        $this->nrows = count($rows);
        $this->omit = [];
        $payloads = $this->payloads($rows, $this->omit);
        $col = $this->columnar($rows);
        $stream = Arrow::writeStream($col);
        $template = Arrow::compile($col);
        $fast = $template->writePayloads($payloads);
        $this->template = ($fast === $stream) ? $template : null;
    }

    public function serializeBytes(mixed $value): string
    {
        $rows = $this->rowsOf($value);
        if ($this->template !== null) {
            $omit = [];
            $fast = $this->template->writePayloads($this->payloads($rows, $omit));
            if ($fast !== null) {
                return $fast;
            }
        }
        return Arrow::writeStream($this->columnar($rows));
    }

    public function deserializeBytes(string $data): mixed
    {
        if ($this->template !== null) {
            $payloads = $this->template->readPayloads($data);
            if ($payloads !== null) {
                $rows = $this->rowsFrom($payloads);
                return $this->batch ? $rows : $rows[0];
            }
        }
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

    /** @return list<array<string,mixed>> */
    private function rowsOf(mixed $value): array
    {
        $rows = $this->batch ? $value : [$value];
        if (!is_array($rows)) {
            throw new \InvalidArgumentException($this->kind);
        }
        return $rows;
    }

    /** @param list<array<string,mixed>> $rows */
    private function columnar(array $rows): mixed
    {
        $b = new TableBuilder();
        match ($this->kind) {
            'message' => self::message($b, $rows),
            'document' => self::document($b, $rows),
            'telemetry' => self::telemetry($b, $rows),
            'strings' => self::strings($b, $rows),
            'event' => self::event($b, $rows),
            default => throw new \InvalidArgumentException($this->kind),
        };
        return $b->build();
    }

    /**
     * Non-empty body buffers in Arrow emit order.
     *
     * @param list<array<string,mixed>> $rows
     * @param array<string,bool> $omit
     * @return list<string>
     */
    private function payloads(array $rows, array &$omit): array
    {
        $out = [];
        match ($this->kind) {
            'message' => self::messagePayloads($rows, $out, $omit),
            'document' => self::documentPayloads($rows, $out, $omit),
            'telemetry' => self::telemetryPayloads($rows, $out, $omit),
            'strings' => self::stringsPayloads($rows, $out, $omit),
            'event' => self::eventPayloads($rows, $out, $omit),
            default => throw new \InvalidArgumentException($this->kind),
        };
        return $out;
    }

    /** @param list<string> $payloads @return list<array<string,mixed>> */
    private function rowsFrom(array $payloads): array
    {
        $cursor = 0;
        $rows = match ($this->kind) {
            'message' => self::messageRows($payloads, $cursor, $this->nrows, $this->omit),
            'document' => self::documentRows($payloads, $cursor, $this->nrows, $this->omit),
            'telemetry' => self::telemetryRows($payloads, $cursor, $this->nrows, $this->omit),
            'strings' => self::stringsRows($payloads, $cursor, $this->nrows, $this->omit),
            'event' => self::eventRows($payloads, $cursor, $this->nrows, $this->omit),
            default => throw new \InvalidArgumentException($this->kind),
        };
        if ($cursor !== count($payloads)) {
            throw new \RuntimeException('gld-arrow payloads');
        }
        return $rows;
    }

    /** @param list<array<string,mixed>> $rows @param list<string> $out @param array<string,bool> $omit */
    private static function messagePayloads(array $rows, array &$out, array &$omit): void
    {
        $n = count($rows);
        $out[] = self::bits($rows, 'f_bool', $n);
        $out[] = Layout::packInts(self::col($rows, 'f_int32'), 4);
        $out[] = Layout::packInts(self::col($rows, 'f_int64'), 8);
        $out[] = self::f64s(self::col($rows, 'f_float64'));
        self::utf8($out, self::col($rows, 'f_string'), 'f_string', $omit);
        $out[] = self::bits($rows, 'f_bool_2', $n);
        $out[] = Layout::packInts(self::col($rows, 'f_int32_2'), 4);
        self::utf8($out, self::col($rows, 'f_string_2'), 'f_string_2', $omit);
    }

    /** @param list<string> $payloads @param array<string,bool> $omit @return list<array<string,mixed>> */
    private static function messageRows(array $payloads, int &$cursor, int $n, array $omit): array
    {
        $bools = self::readBits(self::take($payloads, $cursor), $n);
        $i32 = Layout::unpackInts(self::take($payloads, $cursor), 4, $n);
        $i64 = Layout::unpackInts(self::take($payloads, $cursor), 8, $n);
        $f64 = self::readF64(self::take($payloads, $cursor), $n);
        $s1 = self::readUtf8($payloads, $cursor, $n, $omit['f_string'] ?? false);
        $bools2 = self::readBits(self::take($payloads, $cursor), $n);
        $i32b = Layout::unpackInts(self::take($payloads, $cursor), 4, $n);
        $s2 = self::readUtf8($payloads, $cursor, $n, $omit['f_string_2'] ?? false);
        $rows = [];
        for ($i = 0; $i < $n; $i++) {
            $rows[] = [
                'f_bool' => $bools[$i],
                'f_int32' => $i32[$i],
                'f_int64' => $i64[$i],
                'f_float64' => $f64[$i],
                'f_string' => $s1[$i],
                'f_bool_2' => $bools2[$i],
                'f_int32_2' => $i32b[$i],
                'f_string_2' => $s2[$i],
            ];
        }
        return $rows;
    }

    /** @param list<array<string,mixed>> $rows @param list<string> $out @param array<string,bool> $omit */
    private static function documentPayloads(array $rows, array &$out, array &$omit): void
    {
        self::utf8($out, self::col($rows, 'id'), 'id', $omit);
        $out[] = Layout::packInts(self::col($rows, 'status'), 4);
        $meta = self::col($rows, 'meta');
        self::utf8($out, self::col($meta, 'region'), 'region', $omit);
        $out[] = Layout::packInts(self::col($meta, 'version'), 4);
        $items = self::col($rows, 'items');
        $out[] = self::listOffs($items);
        $flat = self::flatten($items);
        self::utf8($out, self::col($flat, 'sku'), 'sku', $omit);
        self::ints($out, self::col($flat, 'qty'), 4);
        self::ints($out, self::col($flat, 'price_minor'), 8);
    }

    /** @param list<string> $payloads @param array<string,bool> $omit @return list<array<string,mixed>> */
    private static function documentRows(array $payloads, int &$cursor, int $n, array $omit): array
    {
        $ids = self::readUtf8($payloads, $cursor, $n, $omit['id'] ?? false);
        $status = Layout::unpackInts(self::take($payloads, $cursor), 4, $n);
        $regions = self::readUtf8($payloads, $cursor, $n, $omit['region'] ?? false);
        $versions = Layout::unpackInts(self::take($payloads, $cursor), 4, $n);
        $offs = self::readOffs(self::take($payloads, $cursor));
        $child = $offs[$n] ?? 0;
        $skus = self::readUtf8($payloads, $cursor, $child, $omit['sku'] ?? false);
        $qtys = $child === 0 ? [] : Layout::unpackInts(self::take($payloads, $cursor), 4, $child);
        $prices = $child === 0 ? [] : Layout::unpackInts(self::take($payloads, $cursor), 8, $child);
        $rows = [];
        for ($i = 0; $i < $n; $i++) {
            $items = [];
            for ($k = $offs[$i]; $k < $offs[$i + 1]; $k++) {
                $items[] = ['sku' => $skus[$k], 'qty' => $qtys[$k], 'price_minor' => $prices[$k]];
            }
            $rows[] = [
                'id' => $ids[$i],
                'status' => $status[$i],
                'meta' => ['region' => $regions[$i], 'version' => $versions[$i]],
                'items' => $items,
            ];
        }
        return $rows;
    }

    /** @param list<array<string,mixed>> $rows @param list<string> $out @param array<string,bool> $omit */
    private static function telemetryPayloads(array $rows, array &$out, array &$omit): void
    {
        self::utf8($out, self::col($rows, 'source'), 'source', $omit);
        $out[] = Layout::packInts(self::col($rows, 'ts'), 8);
        $tags = self::col($rows, 'tags');
        $out[] = self::listOffs($tags);
        self::utf8($out, self::flatten($tags), 'tags', $omit);
        $values = self::col($rows, 'values');
        $out[] = self::listOffs($values);
        $flat = self::flatten($values);
        if ($flat !== []) {
            $out[] = self::f64s($flat);
        }
    }

    /** @param list<string> $payloads @param array<string,bool> $omit @return list<array<string,mixed>> */
    private static function telemetryRows(array $payloads, int &$cursor, int $n, array $omit): array
    {
        $sources = self::readUtf8($payloads, $cursor, $n, $omit['source'] ?? false);
        $ts = Layout::unpackInts(self::take($payloads, $cursor), 8, $n);
        $tagOff = self::readOffs(self::take($payloads, $cursor));
        $tagN = $tagOff[$n] ?? 0;
        $tagFlat = self::readUtf8($payloads, $cursor, $tagN, $omit['tags'] ?? false);
        $valOff = self::readOffs(self::take($payloads, $cursor));
        $valN = $valOff[$n] ?? 0;
        $valFlat = $valN === 0 ? [] : self::readF64(self::take($payloads, $cursor), $valN);
        $rows = [];
        for ($i = 0; $i < $n; $i++) {
            $rows[] = [
                'source' => $sources[$i],
                'ts' => $ts[$i],
                'tags' => array_slice($tagFlat, $tagOff[$i], $tagOff[$i + 1] - $tagOff[$i]),
                'values' => array_slice($valFlat, $valOff[$i], $valOff[$i + 1] - $valOff[$i]),
            ];
        }
        return $rows;
    }

    /** @param list<array<string,mixed>> $rows @param list<string> $out @param array<string,bool> $omit */
    private static function stringsPayloads(array $rows, array &$out, array &$omit): void
    {
        $items = self::col($rows, 'items');
        $out[] = self::listOffs($items);
        self::utf8($out, self::flatten($items), 'items', $omit);
    }

    /** @param list<string> $payloads @param array<string,bool> $omit @return list<array<string,mixed>> */
    private static function stringsRows(array $payloads, int &$cursor, int $n, array $omit): array
    {
        $offs = self::readOffs(self::take($payloads, $cursor));
        $child = $offs[$n] ?? 0;
        $flat = self::readUtf8($payloads, $cursor, $child, $omit['items'] ?? false);
        $rows = [];
        for ($i = 0; $i < $n; $i++) {
            $rows[] = ['items' => array_slice($flat, $offs[$i], $offs[$i + 1] - $offs[$i])];
        }
        return $rows;
    }

    /** @param list<array<string,mixed>> $rows @param list<string> $out @param array<string,bool> $omit */
    private static function eventPayloads(array $rows, array &$out, array &$omit): void
    {
        self::utf8($out, self::col($rows, 'event_id'), 'event_id', $omit);
        self::utf8($out, self::col($rows, 'event_type'), 'event_type', $omit);
        $out[] = Layout::packInts(self::col($rows, 'occurred_at'), 8);
        self::utf8($out, self::col($rows, 'producer'), 'producer', $omit);
        $attrs = self::col($rows, 'attrs');
        $out[] = self::listOffs($attrs);
        $flat = self::flatten($attrs);
        self::utf8($out, self::col($flat, 'key'), 'key', $omit);
        self::utf8($out, self::col($flat, 'value'), 'value', $omit);
    }

    /** @param list<string> $payloads @param array<string,bool> $omit @return list<array<string,mixed>> */
    private static function eventRows(array $payloads, int &$cursor, int $n, array $omit): array
    {
        $ids = self::readUtf8($payloads, $cursor, $n, $omit['event_id'] ?? false);
        $types = self::readUtf8($payloads, $cursor, $n, $omit['event_type'] ?? false);
        $at = Layout::unpackInts(self::take($payloads, $cursor), 8, $n);
        $producers = self::readUtf8($payloads, $cursor, $n, $omit['producer'] ?? false);
        $offs = self::readOffs(self::take($payloads, $cursor));
        $child = $offs[$n] ?? 0;
        $keys = self::readUtf8($payloads, $cursor, $child, $omit['key'] ?? false);
        $vals = self::readUtf8($payloads, $cursor, $child, $omit['value'] ?? false);
        $rows = [];
        for ($i = 0; $i < $n; $i++) {
            $attrs = [];
            for ($k = $offs[$i]; $k < $offs[$i + 1]; $k++) {
                $attrs[] = ['key' => $keys[$k], 'value' => $vals[$k]];
            }
            $rows[] = [
                'event_id' => $ids[$i],
                'event_type' => $types[$i],
                'occurred_at' => $at[$i],
                'producer' => $producers[$i],
                'attrs' => $attrs,
            ];
        }
        return $rows;
    }

    /** @param list<array<string,mixed>> $rows */
    private static function bits(array $rows, string $key, int $n): string
    {
        $bits = str_repeat("\0", intdiv($n + 7, 8));
        foreach ($rows as $i => $row) {
            if (!$row[$key]) {
                continue;
            }
            $bi = intdiv($i, 8);
            $bits[$bi] = chr(ord($bits[$bi]) | (1 << ($i & 7)));
        }
        return $bits;
    }

    /** @return list<bool> */
    private static function readBits(string $bits, int $n): array
    {
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[] = ((ord($bits[intdiv($i, 8)] ?? "\0") >> ($i & 7)) & 1) === 1;
        }
        return $out;
    }

    /** @param list<string> $out @param list<int> $values */
    private static function ints(array &$out, array $values, int $width): void
    {
        if ($values === []) {
            return;
        }
        $out[] = Layout::packInts($values, $width);
    }

    /** @param list<float> $values */
    private static function f64s(array $values): string
    {
        $raw = '';
        foreach ($values as $v) {
            $raw .= pack('e', $v);
        }
        return $raw;
    }

    /** @return list<float> */
    private static function readF64(string $raw, int $n): array
    {
        if ($n === 0) {
            return [];
        }
        $unpacked = unpack('e*', $raw);
        return $unpacked === false ? [] : array_values($unpacked);
    }

    /** @param list<string> $out @param list<string> $strings @param array<string,bool> $omit */
    private static function utf8(array &$out, array $strings, string $name, array &$omit): void
    {
        $data = '';
        $offs = pack('V', 0);
        $cursor = 0;
        foreach ($strings as $text) {
            $data .= $text;
            $cursor += strlen($text);
            $offs .= pack('V', $cursor);
        }
        $out[] = $offs;
        $omit[$name] = $data === '';
        if ($data !== '') {
            $out[] = $data;
        }
    }

    /** @param list<string> $payloads @return list<string> */
    private static function readUtf8(array $payloads, int &$cursor, int $n, bool $omit): array
    {
        if ($n === 0) {
            self::take($payloads, $cursor);
            return [];
        }
        $offs = self::readOffs(self::take($payloads, $cursor));
        $data = $omit ? '' : self::take($payloads, $cursor);
        $out = [];
        for ($i = 0; $i < $n; $i++) {
            $out[] = substr($data, $offs[$i], $offs[$i + 1] - $offs[$i]);
        }
        return $out;
    }

    /** @param list<list<mixed>> $rows */
    private static function listOffs(array $rows): string
    {
        $offs = pack('V', 0);
        $cursor = 0;
        foreach ($rows as $row) {
            $cursor += count($row);
            $offs .= pack('V', $cursor);
        }
        return $offs;
    }

    /** @return list<int> */
    private static function readOffs(string $raw): array
    {
        $unpacked = unpack('V*', $raw);
        return $unpacked === false ? [0] : array_values($unpacked);
    }

    /** @param list<string> $payloads */
    private static function take(array $payloads, int &$cursor): string
    {
        if (!isset($payloads[$cursor])) {
            throw new \RuntimeException('gld-arrow payload');
        }
        return $payloads[$cursor++];
    }

    /** @param list<list<mixed>> $rows @return list<mixed> */
    private static function flatten(array $rows): array
    {
        $flat = [];
        foreach ($rows as $row) {
            foreach ($row as $item) {
                $flat[] = $item;
            }
        }
        return $flat;
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
