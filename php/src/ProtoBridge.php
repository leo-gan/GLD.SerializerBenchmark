<?php

declare(strict_types=1);

namespace Benchmark;

use Benchmark\V2\BatchDocument;
use Benchmark\V2\BatchEvent;
use Benchmark\V2\BatchMessage;
use Benchmark\V2\BatchStrings;
use Benchmark\V2\BatchTelemetry;
use Benchmark\V2\Document;
use Benchmark\V2\DocumentItem;
use Benchmark\V2\DocumentMeta;
use Benchmark\V2\Event;
use Benchmark\V2\EventAttr;
use Benchmark\V2\Message;
use Benchmark\V2\Strings;
use Benchmark\V2\Telemetry;
use Google\Protobuf\Internal\Message as PbMessage;

final class ProtoBridge
{
    public static function detect(mixed $value): array
    {
        if (self::isList($value)) {
            $first = $value[0] ?? [];
            return [self::kindOf($first), true];
        }
        return [self::kindOf($value), false];
    }

    public static function toProto(mixed $value): PbMessage
    {
        [$kind, $batch] = self::detect($value);
        if ($batch) {
            return match ($kind) {
                'message' => (new BatchMessage())->setItems(array_map(self::toMessage(...), $value)),
                'document' => (new BatchDocument())->setItems(array_map(self::toDocument(...), $value)),
                'telemetry' => (new BatchTelemetry())->setItems(array_map(self::toTelemetry(...), $value)),
                'strings' => (new BatchStrings())->setItems(array_map(self::toStrings(...), $value)),
                'event' => (new BatchEvent())->setItems(array_map(self::toEvent(...), $value)),
                default => throw new \InvalidArgumentException($kind),
            };
        }
        return match ($kind) {
            'message' => self::toMessage($value),
            'document' => self::toDocument($value),
            'telemetry' => self::toTelemetry($value),
            'strings' => self::toStrings($value),
            'event' => self::toEvent($value),
            default => throw new \InvalidArgumentException($kind),
        };
    }

    public static function emptyMessage(mixed $value): PbMessage
    {
        [$kind, $batch] = self::detect($value);
        if ($batch) {
            return match ($kind) {
                'message' => new BatchMessage(),
                'document' => new BatchDocument(),
                'telemetry' => new BatchTelemetry(),
                'strings' => new BatchStrings(),
                'event' => new BatchEvent(),
                default => throw new \InvalidArgumentException($kind),
            };
        }
        return match ($kind) {
            'message' => new Message(),
            'document' => new Document(),
            'telemetry' => new Telemetry(),
            'strings' => new Strings(),
            'event' => new Event(),
            default => throw new \InvalidArgumentException($kind),
        };
    }

    public static function fromProto(PbMessage $msg): mixed
    {
        return match (true) {
            $msg instanceof BatchMessage => array_map(self::fromMessage(...), iterator_to_array($msg->getItems())),
            $msg instanceof BatchDocument => array_map(self::fromDocument(...), iterator_to_array($msg->getItems())),
            $msg instanceof BatchTelemetry => array_map(self::fromTelemetry(...), iterator_to_array($msg->getItems())),
            $msg instanceof BatchStrings => array_map(self::fromStrings(...), iterator_to_array($msg->getItems())),
            $msg instanceof BatchEvent => array_map(self::fromEvent(...), iterator_to_array($msg->getItems())),
            $msg instanceof Message => self::fromMessage($msg),
            $msg instanceof Document => self::fromDocument($msg),
            $msg instanceof Telemetry => self::fromTelemetry($msg),
            $msg instanceof Strings => self::fromStrings($msg),
            $msg instanceof Event => self::fromEvent($msg),
            default => throw new \InvalidArgumentException($msg::class),
        };
    }

    private static function kindOf(mixed $v): string
    {
        if (!is_array($v)) {
            throw new \InvalidArgumentException('expected array fixture');
        }
        if (array_key_exists('f_bool', $v)) {
            return 'message';
        }
        if (array_key_exists('event_id', $v)) {
            return 'event';
        }
        if (array_key_exists('source', $v) && array_key_exists('values', $v)) {
            return 'telemetry';
        }
        if (array_key_exists('id', $v) && array_key_exists('items', $v) && isset($v['meta'])) {
            return 'document';
        }
        if (array_key_exists('items', $v) && isset($v['items'][0]) && is_string($v['items'][0])) {
            return 'strings';
        }
        throw new \InvalidArgumentException('unknown fixture shape');
    }

    private static function isList(mixed $v): bool
    {
        return is_array($v) && array_is_list($v);
    }

    private static function toMessage(array $v): Message
    {
        return (new Message())
            ->setFBool((bool) $v['f_bool'])
            ->setFInt32((int) $v['f_int32'])
            ->setFInt64((int) $v['f_int64'])
            ->setFFloat64((float) $v['f_float64'])
            ->setFString((string) $v['f_string'])
            ->setFBool2((bool) $v['f_bool_2'])
            ->setFInt322((int) $v['f_int32_2'])
            ->setFString2((string) $v['f_string_2']);
    }

    private static function fromMessage(Message $m): array
    {
        return [
            'f_bool' => $m->getFBool(),
            'f_int32' => $m->getFInt32(),
            'f_int64' => $m->getFInt64(),
            'f_float64' => $m->getFFloat64(),
            'f_string' => $m->getFString(),
            'f_bool_2' => $m->getFBool2(),
            'f_int32_2' => $m->getFInt322(),
            'f_string_2' => $m->getFString2(),
        ];
    }

    private static function toDocument(array $v): Document
    {
        $meta = (new DocumentMeta())
            ->setRegion((string) $v['meta']['region'])
            ->setVersion((int) $v['meta']['version']);
        $items = [];
        foreach ($v['items'] as $it) {
            $items[] = (new DocumentItem())
                ->setSku((string) $it['sku'])
                ->setQty((int) $it['qty'])
                ->setPriceMinor((int) $it['price_minor']);
        }
        return (new Document())
            ->setId((string) $v['id'])
            ->setStatus((int) $v['status'])
            ->setMeta($meta)
            ->setItems($items);
    }

    private static function fromDocument(Document $d): array
    {
        $meta = $d->getMeta();
        $items = [];
        foreach ($d->getItems() as $it) {
            $items[] = [
                'sku' => $it->getSku(),
                'qty' => $it->getQty(),
                'price_minor' => $it->getPriceMinor(),
            ];
        }
        return [
            'id' => $d->getId(),
            'status' => $d->getStatus(),
            'meta' => [
                'region' => $meta?->getRegion() ?? '',
                'version' => $meta?->getVersion() ?? 0,
            ],
            'items' => $items,
        ];
    }

    private static function toTelemetry(array $v): Telemetry
    {
        return (new Telemetry())
            ->setSource((string) $v['source'])
            ->setTs((int) $v['ts'])
            ->setTags(array_map('strval', $v['tags']))
            ->setValues(array_map('floatval', $v['values']));
    }

    private static function fromTelemetry(Telemetry $t): array
    {
        return [
            'source' => $t->getSource(),
            'ts' => $t->getTs(),
            'tags' => iterator_to_array($t->getTags()),
            'values' => iterator_to_array($t->getValues()),
        ];
    }

    private static function toStrings(array $v): Strings
    {
        return (new Strings())->setItems(array_map('strval', $v['items']));
    }

    private static function fromStrings(Strings $s): array
    {
        return ['items' => iterator_to_array($s->getItems())];
    }

    private static function toEvent(array $v): Event
    {
        $attrs = [];
        foreach ($v['attrs'] as $a) {
            $attrs[] = (new EventAttr())->setKey((string) $a['key'])->setValue((string) $a['value']);
        }
        return (new Event())
            ->setEventId((string) $v['event_id'])
            ->setEventType((string) $v['event_type'])
            ->setOccurredAt((int) $v['occurred_at'])
            ->setProducer((string) $v['producer'])
            ->setAttrs($attrs);
    }

    private static function fromEvent(Event $e): array
    {
        $attrs = [];
        foreach ($e->getAttrs() as $a) {
            $attrs[] = ['key' => $a->getKey(), 'value' => $a->getValue()];
        }
        return [
            'event_id' => $e->getEventId(),
            'event_type' => $e->getEventType(),
            'occurred_at' => $e->getOccurredAt(),
            'producer' => $e->getProducer(),
            'attrs' => $attrs,
        ];
    }
}
