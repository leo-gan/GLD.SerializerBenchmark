@0xbfc4e8d8c0a1b2c3;
using Java = import "/java.capnp";
$Java.package("benchmark.capnp");
$Java.outerClassname("BenchmarkCapnp");

# Data Model v2 — Cap'n Proto schema (aligned with suite type_ids)

struct Message {
  fBool @0 :Bool;
  fInt32 @1 :Int32;
  fInt64 @2 :Int64;
  fFloat64 @3 :Float64;
  fString @4 :Text;
  fBool2 @5 :Bool;
  fInt32B @6 :Int32;
  fStringB @7 :Text;
}

struct DocumentMeta {
  region @0 :Text;
  version @1 :Int32;
}

struct DocumentItem {
  sku @0 :Text;
  qty @1 :Int32;
  priceMinor @2 :Int64;
}

struct Document {
  id @0 :Text;
  status @1 :Int32;
  meta @2 :DocumentMeta;
  items @3 :List(DocumentItem);
}

struct Telemetry {
  source @0 :Text;
  ts @1 :Int64;
  tags @2 :List(Text);
  values @3 :List(Float64);
}

struct Strings {
  items @0 :List(Text);
}

struct EventAttr {
  key @0 :Text;
  value @1 :Text;
}

struct Event {
  eventId @0 :Text;
  eventType @1 :Text;
  occurredAt @2 :Int64;
  producer @3 :Text;
  attrs @4 :List(EventAttr);
}

struct BatchMessage { items @0 :List(Message); }
struct BatchDocument { items @0 :List(Document); }
struct BatchTelemetry { items @0 :List(Telemetry); }
struct BatchStrings { items @0 :List(Strings); }
struct BatchEvent { items @0 :List(Event); }
