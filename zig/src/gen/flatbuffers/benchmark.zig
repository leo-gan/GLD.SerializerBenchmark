const std = @import("std");

const flatbuffers = @import("flatbuffers");

const @"#schema": flatbuffers.types.Schema = @import("benchmark.zon");

pub const benchmark = struct {
    pub const v2 = struct {
        pub const FixtureKind = enum(i8) {
            pub const @"#kind" = flatbuffers.Kind.Enum;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".enums[0];

            Message = 0,
            Document = 1,
            Telemetry = 2,
            Strings = 3,
            Event = 4,
            BatchMessage = 5,
            BatchDocument = 6,
            BatchTelemetry = 7,
            BatchStrings = 8,
            BatchEvent = 9,
        };

        pub const BatchDocument = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[0];
            pub const @"#constructor" = struct {
                items: ?[]const benchmark.v2.Document = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn items(@"#self": BatchDocument) ?flatbuffers.Vector(benchmark.v2.Document) {
                return flatbuffers.decodeVectorField(benchmark.v2.Document, 0, @"#self".@"#ref");
            }
        };

        pub const BatchEvent = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[1];
            pub const @"#constructor" = struct {
                items: ?[]const benchmark.v2.Event = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn items(@"#self": BatchEvent) ?flatbuffers.Vector(benchmark.v2.Event) {
                return flatbuffers.decodeVectorField(benchmark.v2.Event, 0, @"#self".@"#ref");
            }
        };

        pub const BatchMessage = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[2];
            pub const @"#constructor" = struct {
                items: ?[]const benchmark.v2.Message = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn items(@"#self": BatchMessage) ?flatbuffers.Vector(benchmark.v2.Message) {
                return flatbuffers.decodeVectorField(benchmark.v2.Message, 0, @"#self".@"#ref");
            }
        };

        pub const BatchStrings = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[3];
            pub const @"#constructor" = struct {
                items: ?[]const benchmark.v2.Strings = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn items(@"#self": BatchStrings) ?flatbuffers.Vector(benchmark.v2.Strings) {
                return flatbuffers.decodeVectorField(benchmark.v2.Strings, 0, @"#self".@"#ref");
            }
        };

        pub const BatchTelemetry = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[4];
            pub const @"#constructor" = struct {
                items: ?[]const benchmark.v2.Telemetry = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn items(@"#self": BatchTelemetry) ?flatbuffers.Vector(benchmark.v2.Telemetry) {
                return flatbuffers.decodeVectorField(benchmark.v2.Telemetry, 0, @"#self".@"#ref");
            }
        };

        pub const Document = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[5];
            pub const @"#constructor" = struct {
                id: ?[]const u8 = null,
                status: i32 = 0,
                meta: ?benchmark.v2.DocumentMeta = null,
                items: ?[]const benchmark.v2.DocumentItem = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn id(@"#self": Document) ?flatbuffers.String {
                return flatbuffers.decodeStringField(0, @"#self".@"#ref");
            }

            pub fn status(@"#self": Document) i32 {
                return flatbuffers.decodeScalarField(i32, 1, @"#self".@"#ref", 0);
            }

            pub fn meta(@"#self": Document) ?benchmark.v2.DocumentMeta {
                return flatbuffers.decodeTableField(benchmark.v2.DocumentMeta, 2, @"#self".@"#ref");
            }

            pub fn items(@"#self": Document) ?flatbuffers.Vector(benchmark.v2.DocumentItem) {
                return flatbuffers.decodeVectorField(benchmark.v2.DocumentItem, 3, @"#self".@"#ref");
            }
        };

        pub const DocumentItem = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[6];
            pub const @"#constructor" = struct {
                sku: ?[]const u8 = null,
                qty: i32 = 0,
                price_minor: i64 = 0,
            };

            @"#ref": flatbuffers.Ref,

            pub fn sku(@"#self": DocumentItem) ?flatbuffers.String {
                return flatbuffers.decodeStringField(0, @"#self".@"#ref");
            }

            pub fn qty(@"#self": DocumentItem) i32 {
                return flatbuffers.decodeScalarField(i32, 1, @"#self".@"#ref", 0);
            }

            pub fn price_minor(@"#self": DocumentItem) i64 {
                return flatbuffers.decodeScalarField(i64, 2, @"#self".@"#ref", 0);
            }
        };

        pub const DocumentMeta = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[7];
            pub const @"#constructor" = struct {
                region: ?[]const u8 = null,
                version: i32 = 0,
            };

            @"#ref": flatbuffers.Ref,

            pub fn region(@"#self": DocumentMeta) ?flatbuffers.String {
                return flatbuffers.decodeStringField(0, @"#self".@"#ref");
            }

            pub fn version(@"#self": DocumentMeta) i32 {
                return flatbuffers.decodeScalarField(i32, 1, @"#self".@"#ref", 0);
            }
        };

        pub const Event = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[8];
            pub const @"#constructor" = struct {
                event_id: ?[]const u8 = null,
                event_type: ?[]const u8 = null,
                occurred_at: i64 = 0,
                producer: ?[]const u8 = null,
                attrs: ?[]const benchmark.v2.EventAttr = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn event_id(@"#self": Event) ?flatbuffers.String {
                return flatbuffers.decodeStringField(0, @"#self".@"#ref");
            }

            pub fn event_type(@"#self": Event) ?flatbuffers.String {
                return flatbuffers.decodeStringField(1, @"#self".@"#ref");
            }

            pub fn occurred_at(@"#self": Event) i64 {
                return flatbuffers.decodeScalarField(i64, 2, @"#self".@"#ref", 0);
            }

            pub fn producer(@"#self": Event) ?flatbuffers.String {
                return flatbuffers.decodeStringField(3, @"#self".@"#ref");
            }

            pub fn attrs(@"#self": Event) ?flatbuffers.Vector(benchmark.v2.EventAttr) {
                return flatbuffers.decodeVectorField(benchmark.v2.EventAttr, 4, @"#self".@"#ref");
            }
        };

        pub const EventAttr = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[9];
            pub const @"#constructor" = struct {
                key: ?[]const u8 = null,
                value: ?[]const u8 = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn key(@"#self": EventAttr) ?flatbuffers.String {
                return flatbuffers.decodeStringField(0, @"#self".@"#ref");
            }

            pub fn value(@"#self": EventAttr) ?flatbuffers.String {
                return flatbuffers.decodeStringField(1, @"#self".@"#ref");
            }
        };

        pub const FixtureRoot = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[10];
            pub const @"#constructor" = struct {
                kind: benchmark.v2.FixtureKind = @enumFromInt(0),
                message: ?benchmark.v2.Message = null,
                document: ?benchmark.v2.Document = null,
                telemetry: ?benchmark.v2.Telemetry = null,
                strings: ?benchmark.v2.Strings = null,
                event: ?benchmark.v2.Event = null,
                batch_message: ?benchmark.v2.BatchMessage = null,
                batch_document: ?benchmark.v2.BatchDocument = null,
                batch_telemetry: ?benchmark.v2.BatchTelemetry = null,
                batch_strings: ?benchmark.v2.BatchStrings = null,
                batch_event: ?benchmark.v2.BatchEvent = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn kind(@"#self": FixtureRoot) benchmark.v2.FixtureKind {
                return flatbuffers.decodeEnumField(benchmark.v2.FixtureKind, 0, @"#self".@"#ref", @enumFromInt(0));
            }

            pub fn message(@"#self": FixtureRoot) ?benchmark.v2.Message {
                return flatbuffers.decodeTableField(benchmark.v2.Message, 1, @"#self".@"#ref");
            }

            pub fn document(@"#self": FixtureRoot) ?benchmark.v2.Document {
                return flatbuffers.decodeTableField(benchmark.v2.Document, 2, @"#self".@"#ref");
            }

            pub fn telemetry(@"#self": FixtureRoot) ?benchmark.v2.Telemetry {
                return flatbuffers.decodeTableField(benchmark.v2.Telemetry, 3, @"#self".@"#ref");
            }

            pub fn strings(@"#self": FixtureRoot) ?benchmark.v2.Strings {
                return flatbuffers.decodeTableField(benchmark.v2.Strings, 4, @"#self".@"#ref");
            }

            pub fn event(@"#self": FixtureRoot) ?benchmark.v2.Event {
                return flatbuffers.decodeTableField(benchmark.v2.Event, 5, @"#self".@"#ref");
            }

            pub fn batch_message(@"#self": FixtureRoot) ?benchmark.v2.BatchMessage {
                return flatbuffers.decodeTableField(benchmark.v2.BatchMessage, 6, @"#self".@"#ref");
            }

            pub fn batch_document(@"#self": FixtureRoot) ?benchmark.v2.BatchDocument {
                return flatbuffers.decodeTableField(benchmark.v2.BatchDocument, 7, @"#self".@"#ref");
            }

            pub fn batch_telemetry(@"#self": FixtureRoot) ?benchmark.v2.BatchTelemetry {
                return flatbuffers.decodeTableField(benchmark.v2.BatchTelemetry, 8, @"#self".@"#ref");
            }

            pub fn batch_strings(@"#self": FixtureRoot) ?benchmark.v2.BatchStrings {
                return flatbuffers.decodeTableField(benchmark.v2.BatchStrings, 9, @"#self".@"#ref");
            }

            pub fn batch_event(@"#self": FixtureRoot) ?benchmark.v2.BatchEvent {
                return flatbuffers.decodeTableField(benchmark.v2.BatchEvent, 10, @"#self".@"#ref");
            }
        };

        pub const Message = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[11];
            pub const @"#constructor" = struct {
                f_bool: bool = false,
                f_int32: i32 = 0,
                f_int64: i64 = 0,
                f_float64: f64 = 0,
                f_string: ?[]const u8 = null,
                f_bool_2: bool = false,
                f_int32_2: i32 = 0,
                f_string_2: ?[]const u8 = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn f_bool(@"#self": Message) bool {
                return flatbuffers.decodeScalarField(bool, 0, @"#self".@"#ref", false);
            }

            pub fn f_int32(@"#self": Message) i32 {
                return flatbuffers.decodeScalarField(i32, 1, @"#self".@"#ref", 0);
            }

            pub fn f_int64(@"#self": Message) i64 {
                return flatbuffers.decodeScalarField(i64, 2, @"#self".@"#ref", 0);
            }

            pub fn f_float64(@"#self": Message) f64 {
                return flatbuffers.decodeScalarField(f64, 3, @"#self".@"#ref", 0);
            }

            pub fn f_string(@"#self": Message) ?flatbuffers.String {
                return flatbuffers.decodeStringField(4, @"#self".@"#ref");
            }

            pub fn f_bool_2(@"#self": Message) bool {
                return flatbuffers.decodeScalarField(bool, 5, @"#self".@"#ref", false);
            }

            pub fn f_int32_2(@"#self": Message) i32 {
                return flatbuffers.decodeScalarField(i32, 6, @"#self".@"#ref", 0);
            }

            pub fn f_string_2(@"#self": Message) ?flatbuffers.String {
                return flatbuffers.decodeStringField(7, @"#self".@"#ref");
            }
        };

        pub const Strings = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[12];
            pub const @"#constructor" = struct {
                items: ?[]const []const u8 = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn items(@"#self": Strings) ?flatbuffers.Vector(flatbuffers.String) {
                return flatbuffers.decodeVectorField(flatbuffers.String, 0, @"#self".@"#ref");
            }
        };

        pub const Telemetry = struct {
            pub const @"#kind" = flatbuffers.Kind.Table;
            pub const @"#root" = &@"#schema";
            pub const @"#type" = &@"#schema".tables[13];
            pub const @"#constructor" = struct {
                source: ?[]const u8 = null,
                ts: i64 = 0,
                tags: ?[]const []const u8 = null,
                values: ?[]const f64 = null,
            };

            @"#ref": flatbuffers.Ref,

            pub fn source(@"#self": Telemetry) ?flatbuffers.String {
                return flatbuffers.decodeStringField(0, @"#self".@"#ref");
            }

            pub fn ts(@"#self": Telemetry) i64 {
                return flatbuffers.decodeScalarField(i64, 1, @"#self".@"#ref", 0);
            }

            pub fn tags(@"#self": Telemetry) ?flatbuffers.Vector(flatbuffers.String) {
                return flatbuffers.decodeVectorField(flatbuffers.String, 2, @"#self".@"#ref");
            }

            pub fn values(@"#self": Telemetry) ?flatbuffers.Vector(f64) {
                return flatbuffers.decodeVectorField(f64, 3, @"#self".@"#ref");
            }
        };
    };
};
