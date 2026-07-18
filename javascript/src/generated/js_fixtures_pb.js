/**
 * Data Model v2 schemas for js_fixtures.proto.
 * Built at load time from a FileDescriptorProto so the suite does not require
 * re-running protoc-gen-es after schema edits (run `npm run generate:protobuf-es`
 * when you want static stubs instead).
 */
/* eslint-disable */
import { create, toBinary } from '@bufbuild/protobuf';
import { fileDesc, messageDesc } from '@bufbuild/protobuf/codegenv2';
import {
  FileDescriptorProtoSchema,
  FieldDescriptorProto_Type as T,
  FieldDescriptorProto_Label as L,
} from '@bufbuild/protobuf/wkt';
import { base64Encode } from '@bufbuild/protobuf/wire';

const OPT = L.OPTIONAL;
const REP = L.REPEATED;

function field(name, number, type, extra = {}) {
  return { name, number, label: extra.repeated ? REP : OPT, type, typeName: extra.typeName };
}

const pkg = 'js_fixtures';
const fdp = create(FileDescriptorProtoSchema, {
  name: 'js_fixtures.proto',
  package: pkg,
  syntax: 'proto3',
  messageType: [
    {
      name: 'Message',
      field: [
        field('f_bool', 1, T.BOOL),
        field('f_int32', 2, T.INT32),
        field('f_int64', 3, T.INT64),
        field('f_float64', 4, T.DOUBLE),
        field('f_string', 5, T.STRING),
        field('f_bool_2', 6, T.BOOL),
        field('f_int32_2', 7, T.INT32),
        field('f_string_2', 8, T.STRING),
      ],
    },
    {
      name: 'BatchMessage',
      field: [field('items', 1, T.MESSAGE, { repeated: true, typeName: `.${pkg}.Message` })],
    },
    {
      name: 'DocumentMeta',
      field: [field('region', 1, T.STRING), field('version', 2, T.INT32)],
    },
    {
      name: 'DocumentItem',
      field: [
        field('sku', 1, T.STRING),
        field('qty', 2, T.INT32),
        field('price_minor', 3, T.INT64),
      ],
    },
    {
      name: 'Document',
      field: [
        field('id', 1, T.STRING),
        field('status', 2, T.INT32),
        field('meta', 3, T.MESSAGE, { typeName: `.${pkg}.DocumentMeta` }),
        field('items', 4, T.MESSAGE, { repeated: true, typeName: `.${pkg}.DocumentItem` }),
      ],
    },
    {
      name: 'BatchDocument',
      field: [field('items', 1, T.MESSAGE, { repeated: true, typeName: `.${pkg}.Document` })],
    },
    {
      name: 'Telemetry',
      field: [
        field('source', 1, T.STRING),
        field('ts', 2, T.INT64),
        field('tags', 3, T.STRING, { repeated: true }),
        field('values', 4, T.DOUBLE, { repeated: true }),
      ],
    },
    {
      name: 'BatchTelemetry',
      field: [field('items', 1, T.MESSAGE, { repeated: true, typeName: `.${pkg}.Telemetry` })],
    },
    {
      name: 'Strings',
      field: [field('items', 1, T.STRING, { repeated: true })],
    },
    {
      name: 'BatchStrings',
      field: [field('items', 1, T.MESSAGE, { repeated: true, typeName: `.${pkg}.Strings` })],
    },
    {
      name: 'EventAttr',
      field: [field('key', 1, T.STRING), field('value', 2, T.STRING)],
    },
    {
      name: 'Event',
      field: [
        field('event_id', 1, T.STRING),
        field('event_type', 2, T.STRING),
        field('occurred_at', 3, T.INT64),
        field('producer', 4, T.STRING),
        field('attrs', 5, T.MESSAGE, { repeated: true, typeName: `.${pkg}.EventAttr` }),
      ],
    },
    {
      name: 'BatchEvent',
      field: [field('items', 1, T.MESSAGE, { repeated: true, typeName: `.${pkg}.Event` })],
    },
  ],
});

const b64 = base64Encode(toBinary(FileDescriptorProtoSchema, fdp), 'std_raw');

/** Describes the file js_fixtures.proto. */
export const file_js_fixtures = /*@__PURE__*/ fileDesc(b64);

export const MessageSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 0);
export const BatchMessageSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 1);
export const DocumentMetaSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 2);
export const DocumentItemSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 3);
export const DocumentSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 4);
export const BatchDocumentSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 5);
export const TelemetrySchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 6);
export const BatchTelemetrySchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 7);
export const StringsSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 8);
export const BatchStringsSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 9);
export const EventAttrSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 10);
export const EventSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 11);
export const BatchEventSchema = /*@__PURE__*/ messageDesc(file_js_fixtures, 12);

