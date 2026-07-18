// Data Model v2 schemas for js_fixtures.proto (see js_fixtures_pb.js).
/* eslint-disable */

import type { GenFile, GenMessage } from "@bufbuild/protobuf/codegenv2";
import type { Message } from "@bufbuild/protobuf";

export declare const file_js_fixtures: GenFile;

export declare type MessageV2 = Message<"js_fixtures.Message"> & {
  fBool: boolean;
  fInt32: number;
  fInt64: bigint;
  fFloat64: number;
  fString: string;
  fBool2: boolean;
  fInt322: number;
  fString2: string;
};
export declare const MessageSchema: GenMessage<MessageV2>;

export declare type BatchMessage = Message<"js_fixtures.BatchMessage"> & {
  items: MessageV2[];
};
export declare const BatchMessageSchema: GenMessage<BatchMessage>;

export declare type DocumentMeta = Message<"js_fixtures.DocumentMeta"> & {
  region: string;
  version: number;
};
export declare const DocumentMetaSchema: GenMessage<DocumentMeta>;

export declare type DocumentItem = Message<"js_fixtures.DocumentItem"> & {
  sku: string;
  qty: number;
  priceMinor: bigint;
};
export declare const DocumentItemSchema: GenMessage<DocumentItem>;

export declare type DocumentMsg = Message<"js_fixtures.Document"> & {
  id: string;
  status: number;
  meta?: DocumentMeta;
  items: DocumentItem[];
};
export declare const DocumentSchema: GenMessage<DocumentMsg>;

export declare type BatchDocument = Message<"js_fixtures.BatchDocument"> & {
  items: DocumentMsg[];
};
export declare const BatchDocumentSchema: GenMessage<BatchDocument>;

export declare type TelemetryMsg = Message<"js_fixtures.Telemetry"> & {
  source: string;
  ts: bigint;
  tags: string[];
  values: number[];
};
export declare const TelemetrySchema: GenMessage<TelemetryMsg>;

export declare type BatchTelemetry = Message<"js_fixtures.BatchTelemetry"> & {
  items: TelemetryMsg[];
};
export declare const BatchTelemetrySchema: GenMessage<BatchTelemetry>;

export declare type StringsMsg = Message<"js_fixtures.Strings"> & {
  items: string[];
};
export declare const StringsSchema: GenMessage<StringsMsg>;

export declare type BatchStrings = Message<"js_fixtures.BatchStrings"> & {
  items: StringsMsg[];
};
export declare const BatchStringsSchema: GenMessage<BatchStrings>;

export declare type EventAttr = Message<"js_fixtures.EventAttr"> & {
  key: string;
  value: string;
};
export declare const EventAttrSchema: GenMessage<EventAttr>;

export declare type EventMsg = Message<"js_fixtures.Event"> & {
  eventId: string;
  eventType: string;
  occurredAt: bigint;
  producer: string;
  attrs: EventAttr[];
};
export declare const EventSchema: GenMessage<EventMsg>;

export declare type BatchEvent = Message<"js_fixtures.BatchEvent"> & {
  items: EventMsg[];
};
export declare const BatchEventSchema: GenMessage<BatchEvent>;

