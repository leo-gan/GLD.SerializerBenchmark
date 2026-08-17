# Experiment plan

This folder is a laboratory notebook. Each experiment answers **one** question.

Two kinds of people use it:

- A **builder** has to choose a library for a real service.
- A **researcher** has to know whether a ranking is a real difference or an accident of how we measured.

The writing is for a first-year university student in science or engineering. If a word is not everyday English, we define it in the next sentence.

After every experiment we write what happened. If the result changes the next question, we change that question. We do not rewrite old results.

---

## What we study

A running program holds values in memory: numbers, words, lists, nested records. To send a value to another program, or to store it, we must **write it as bytes**. Later someone must **read those bytes back** into a value. A library that does this is a **serializer**.

**JSON** is a text format people can read. Public web services almost always use it, because browsers, phones, and partners already understand it.

Other libraries write **bytes that are not meant for a person to read**. We will call that **binary**. Those libraries were built because someone had a concrete problem, not because “binary” is fashionable.

| Problem someone had | What they built |
|---------------------|-----------------|
| Inside Google, XML messages were large and slow | **Protocol Buffers**: each field has a number; you share a small description file |
| Hadoop, and later Kafka, needed old and new software to run at the same time for years | **Avro**: the description of the fields can travel with the data |
| Facebook had services in many languages that had to call each other | **Thrift** |
| Turning a value into bytes was itself too slow (Kenton Varda, after Protocol Buffers v2) | **Cap’n Proto**: the bytes on the wire are already laid out like the value in memory |
| A game cannot build a full object for every field it will never read | **FlatBuffers**: read one field from the received bytes |
| JSON was too large for services inside one company, and the team did not want a description file | **MessagePack**: the same kinds of values as JSON, but as compact bytes |
| Tiny devices needed a published standard, and a very small writer program | **CBOR** (an Internet standard) |
| MongoDB needed JSON-like records on disk that a reader can skip through quickly | **BSON** |
| Elasticsearch wanted JSON-like values without JSON text | **Smile** |
| A cache used by only one language wanted to store rich objects | **pickle** (Python), **gob** (Go), Java’s built-in writer, **Kryo**, **Fory** |
| A microcontroller could not fit Google’s Protocol Buffers library | **nanopb**, **postcard**, **QCBOR**, **ArduinoJson** |
| JSON was already required; only the reader was too slow | **orjson**, **simdjson**, **sonic** — faster libraries, same JSON text |
| A public service must check types, not only read text | **pydantic** |

A common mistake: someone sees “binary is faster,” changes the public web service, and then spends months helping partners who can no longer use ordinary tools. We ask a **narrow question** first. We measure only that question. Then we decide.

---

## Rules

1. **One programming language at a time.** A Python number and a Go number are not comparable. The clocks and the memory systems differ.
2. **One kind of sample at a time.** A flat record is not an order with line items, and not a list of sensor numbers.
3. **Compare libraries that do the same job.** JSON libraries against JSON libraries. We mix formats only when the question is “should we change format?”
4. **Write the finding before the next experiment.** The next question may change.

**Size** (how many bytes) is the only number that is roughly fair across languages, and only when both sides write the same description of the fields (for example the same Protocol Buffers file). **Time** is never a fair contest across languages.

---

## What we record

| What | Meaning |
|------|---------|
| **Write time** | How long the library takes to turn the sample into bytes |
| **Read time** | How long it takes to turn those bytes back into a value |
| **Size** | How many bytes were written |
| **Same information?** | After reading, do we still have the same numbers and words? A fast library that loses data is not a win |

We also note **how the library was called**:

- **In memory**: write into a block of bytes, then read that block. Typical for a cache or a small request body.
- **Through a stream**: write as you go, as you would to a file. Typical for a file or a network socket.

Some libraries do not really write as they go. They build the whole result and then copy it. We label that **copied**, and we do not treat it as proof that streaming is free.

We drop the first trial (the computer is still warming up). We may set aside rare stalls. Then we take the **middle value** (the median). The raw file of every trial is kept.

We never overwrite the published website tables when we run an experiment.

---

## The samples (this is the data we measure)

Each experiment is one **question**. All settings live in that folder’s **`experiment.yaml`** (the record, the languages, the libraries). Change that file to change the experiment. The saved record (`sample.json`) is **shared**. Each language run lives in a subfolder and holds only that language’s times and result files.

Experiment 1 builds the shared record with [`01-json-library-bakeoff/python/save_sample.py`](01-json-library-bakeoff/python/save_sample.py) → [`01-json-library-bakeoff/sample.json`](01-json-library-bakeoff/sample.json).

A dashboard should load [`01-json-library-bakeoff/results.json`](01-json-library-bakeoff/results.json). Raw run logs stay on the machine that timed them and are **not** in git. Saved `results.md` / `results.json` are enough.

Preview copies for experiments not yet opened live in [`samples/`](samples/).

### Sample A — one order (`document`)

Saved: [`samples/document.n1.json`](samples/document.n1.json)  
Used by: Experiment 1 (and 6, 7, 8, 12)

This is one record, like a small order: an id, a status, a region, a version, and **eight line items**. Each line item has a stock-keeping code, a quantity, and a price in cents.

```json
{
  "id": "btimcpxm",
  "status": 4,
  "meta": { "region": "al", "version": 3 },
  "items": [
    { "sku": "ytgl",         "qty": 10, "price_minor": 55613 },
    { "sku": "sdwkhokqmf",   "qty": 38, "price_minor": 2461 },
    { "sku": "gojhtifpuep",  "qty": 97, "price_minor": 90854 },
    { "sku": "zia",          "qty": 79, "price_minor": 67315 },
    { "sku": "pnjt",         "qty": 61, "price_minor": 32619 },
    { "sku": "tftjldmqrott", "qty": 54, "price_minor": 90365 },
    { "sku": "uciperj",      "qty": 78, "price_minor": 60676 },
    { "sku": "eheam",        "qty": 39, "price_minor": 80173 }
  ]
}
```

The words look random because a small number generator built them. That is on purpose: every run with seed 42 produces the same words.

### Sample B — one flat record (`message`)

Saved: [`samples/message.n1.json`](samples/message.n1.json)  
Used by: Experiment 2 (and 3, 10)

Eight fields, no nesting. Closer to a small request between two services than to an order.

```json
{
  "f_bool": true,
  "f_int32": 442269,
  "f_int64": 446816,
  "f_float64": 649.1968904313869,
  "f_string": "xljybqxfemz",
  "f_bool_2": false,
  "f_int32_2": 598855,
  "f_string_2": "eobwzfgdqglt"
}
```

### Sample C — one sensor record (`telemetry`)

Saved: [`samples/telemetry.points-8.json`](samples/telemetry.points-8.json) (and 32, 128, 512)  
Used by: Experiment 4 (and 9)

A source name, a time (milliseconds since 1970-01-01 UTC), two tags, and a list of numbers. Experiment 4 grows the list: 8, 32, 128, then 512 numbers. Here is the 8-number record:

```json
{
  "source": "bwd",
  "ts": 1704103565427,
  "tags": ["kvlhje", "cshtvh"],
  "values": [86.95, 80.86, 13.34, 21.92, 12.73, 68.79, 80.94, 40.86]
}
```

(The file stores the full decimals. The numbers above are rounded so this page stays readable.)

### Sample D — one event (`event`)

Saved: [`samples/event.n1.json`](samples/event.n1.json)  
Used by: Experiment 5

A fact on a log: who produced it, when, what kind, and four extra attributes.

```json
{
  "event_id": "hwvrjkalkhp",
  "event_type": "qldjcfyvr",
  "occurred_at": 1704142140270,
  "producer": "iytknyg",
  "attrs": [
    { "key": "zijtxz",      "value": "nwugys" },
    { "key": "atwymdxchav", "value": "knrgdho" },
    { "key": "joy",         "value": "rruteloqk" },
    { "key": "plfvkeworb",  "value": "mvxbhvr" }
  ]
}
```

### Sample E — a list of words (`strings`)

Saved: [`samples/strings.n1.json`](samples/strings.n1.json)  
Used by: Experiments 8 and 9

Thirty-two short words. A few words repeat (about one in ten), so a compressor has something to work with. The full list is in the file. The first few are: `onnmcmdfqriecps`, `nbfhfgtn`, `oronfndvtdn`, …

### One hundred records in one write

Some experiments write **one hundred** records in a single call (a batch). We do not paste all hundred here. The runner builds record 0, record 1, … record 99 with the same builder and seed. Record 0 is the JSON you see above. That experiment’s `save_sample.py` will write the full list when we open the experiment.

---

## The list of experiments

| # | Status | Question |
|---|--------|----------|
| 1 | **done** (2026-08-16) | If we must keep JSON, which Python JSON library is best for Sample A? |
| 2 | **done** (2026-08-16, [PR #84](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/84)) | On Sample B, how do ordinary JSON, MessagePack, and Protocol Buffers compare? |
| 3 | **done** (2026-08-16, [PR #85](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/85)) | How much faster is a one-language library than a library other languages can read? |
| 4 | **done** (2026-08-16, [PR #87](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/87)) | As Sample C grows from 8 to 512 numbers, when is JSON too large? |
| 5 | **done** (2026-08-17) | On Sample D, how do Avro, Protocol Buffers, and JSON compare on size and write time? |
| 6 | **done** (2026-08-17) | On Sample A, do BSON, Smile, and Ion beat JSON and MessagePack? |
| 7 | **done** (2026-08-17) | On Sample A, how do FlatBuffers and Cap’n Proto split write time and read time? |
| 8 | **done** (2026-08-17) | On Sample A and Sample E, how much slower are YAML, TOML, and XML than JSON? |
| 9 | planned | After gzip or zstd, does JSON stay larger than binary? |
| 10 | planned | Does the winner at 1 record stay the winner at 100 records? |
| 11 | planned | When we write as if to a file, does the ranking change? |
| 12 | **done** (2026-08-17, [PR #89](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/89)) | If **one** Java library writes JSON and also writes MessagePack, how much of the difference is the format? |
| 13 | **done** (2026-08-17, [PR #90](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/90)) | Do Experiment 1 ranks stay the same if we change the sample or the cleaning rule? |

Run **1, then 2, then 3, then 4, then 12, then 13** first, unless a result forces a detour.

---

## Experiment 1 — If we must keep JSON, which Python library should we use?

**Status:** done for Python (2026-08-16); other languages in the same folder.  
**Folder:** [01-json-library-bakeoff](01-json-library-bakeoff/). Combined page: [results.md](01-json-library-bakeoff/results.md). Combined JSON: [results.json](01-json-library-bakeoff/results.json).  
**Sample:** Sample A, one record, saved as [01-json-library-bakeoff/sample.json](01-json-library-bakeoff/sample.json).

### The question

A public web service almost always speaks JSON. Changing that is expensive: every partner, every browser, every log line has to change.

The first question is not “is binary faster?” It is:

> For Sample A, in Python, writing into memory: which JSON libraries write and read quickly, and do they write files of similar size?

If a better JSON library already meets the need, we should not change the public format.

### Why these libraries exist

**orjson**, **rapidjson**, **simdjson**, and **sonic** exist because the format was already JSON and only the library was slow.

**pydantic** exists to **check** types and values at the door of a service, not to win a speed contest.

### Who we compare

Only Python libraries that write JSON text:

| Name in the log | What it is |
|-----------------|------------|
| `json` | Ships with Python. The familiar starting point. |
| `orjson` | A fast JSON writer. The heavy work is in Rust. |
| `rapidjson` | A fast JSON writer. The heavy work is in C++. |
| `msgspec` | Checks the shape while it reads and writes. In this project it writes a **list of values**, not `{"id": ...}`. Smaller, but not the JSON a public website usually sends. |
| `pydantic` | Builds a model and checks types. Used at the public door of many Python services. |
| `mashumaro` | A typed helper that uses `orjson` for the actual text. |
| `serpyco-rs` | Another typed helper that uses `orjson` for the actual text. |

We do **not** compare these to MessagePack, Protocol Buffers, or `pickle` here.

### How we decide

| If we see… | Then… |
|------------|--------|
| The fastest library is only a little faster than `json` | The built-in library is good enough for this sample |
| A fast library is many times faster than `json` **and writes the same `{"id": ...}` text** | Stay on JSON. Change the library, not the format. |
| `pydantic` is much slower | That extra time is **checking**. Useful at the public door. Costly on every call inside the company. |
| One library writes a much smaller file | Check the text. If it is a list `[...]` instead of named fields, it is not the same public JSON. |

### Costs and benefits

- Checking types protects the service. It will lose a pure speed contest. That is not a defect.
- A library that writes a list of values can be smaller and still call itself JSON. Partners who expect `{"sku": ...}` cannot read `[...]` without a private agreement.
- Several Python JSON libraries first build the whole text and then copy it. A “stream” time that matches the in-memory time is not proof of writing as you go.

### What this experiment cannot tell us

- Whether JSON is fast enough on a real network (we do not measure the network)
- Whether the ranking holds for Sample B, Sample E, or 100 records in one write
- Whether another language’s JSON libraries rank the same way
- Whether a binary format would be better (Experiment 2)

### What we found (2026-08-16)

On Sample A, `json` took about **22 microseconds** to write and read. `orjson` took about **4 microseconds** — about **five and a half times** less — and wrote the **same** named JSON (**448** bytes; **229** after gzip). `pydantic` was slower than `json` when reading, because it also checks types. `msgspec` was almost as fast as `orjson` but wrote only **192** bytes: it writes a list of values, not named fields.

For a public service that must send ordinary named JSON, **`orjson` is the fair winner**. Changing the JSON library is enough to gain a large speed-up. We have not yet earned the right to change the format.

**What this changes later:** Experiment 2 must put **ordinary named JSON** (`orjson`, and `json` as the familiar starting point) on the JSON side. Do not use `msgspec` as “the JSON side.” Its smaller size is a different kind of text.

---

## Experiment 2 — Should an internal service leave JSON?

**Status:** done for all nine languages (2026-08-16).  
**Folder:** [02-flat-record-formats](02-flat-record-formats/). Combined page: [results.md](02-flat-record-formats/results.md). Combined JSON: [results.json](02-flat-record-formats/results.json).  
**Sample:** Sample B, one record, and again 100 records in one write, saved as [02-flat-record-formats/sample.json](02-flat-record-formats/sample.json).

### The question

> For Sample B, in each language, how do ordinary named JSON, MessagePack, and Protocol Buffers compare on write time, read time, and size? Is the gap large enough to justify a new shared description of the fields?

### Why these formats exist

- **Protocol Buffers** (Google): smaller and faster than XML. Each field has a number. You share a `.proto` file. You may add fields. You must never reuse a number. The bytes are not readable without that file.
- **MessagePack**: the same kinds of values as JSON (maps, lists, numbers, text), stored as compact bytes. No description file. Built because JSON was too large inside one company, and the team did not want a `.proto` file.
- **JSON** on an internal path is “keep one format everywhere.” Experiment 1 showed the library still matters: we use `orjson` as the serious JSON side, and `json` as the familiar starting point.

### Real situation

Two services you control exchange small, stable records on a private network. There are no browsers on this path. You *may* leave JSON. Should you?

If you later repeat this in Go or Java, that is the same question in the language you actually ship. Do not compare Python times to Go times.

### Who we compare

| Side | Python libraries | Why |
|------|------------------|-----|
| Ordinary named JSON | `orjson`, and `json` | What Experiment 1 told us to use |
| MessagePack | `msgpack`, optionally `msgspec-msgpack` | Compact, no description file |
| Protocol Buffers | `protobuf` | Shared `.proto` file |
| Not in this comparison | `msgspec` JSON (list shape), `pickle` | Different text; Python-only |

A Python-only library is not a candidate here. That is Experiment 3.

### How we decide

| If we see… | Then… |
|------------|--------|
| `orjson` already meets a tight time and size budget | Keep JSON. Do not pay for a new description file. |
| MessagePack is clearly smaller or faster, and the team will check the data themselves | MessagePack is a fair internal choice |
| Protocol Buffers is clearly smaller or faster, and two languages will share the path | Prefer Protocol Buffers. The shared file is the product, not only the speed. |
| Gaps are small (less than about 2× on this tiny record) | The format is not the bottleneck. Look at the network and the web framework first. |

### Costs and benefits

| | JSON with names | MessagePack | Protocol Buffers |
|--|-----------------|-------------|------------------|
| A person can read it | Yes | No | No (need a decoder) |
| Shared description of fields | Optional | Only if you write one yourselves | Yes (field numbers) |
| Works in many languages | Yes | Usually | Yes, where the generator exists |
| Years of old and new software together | You must invent a process | You must invent a process | Designed for adding fields |
| Debug at 3 a.m. | Easy | Medium | Needs extra tools |
| Fit for stable, dense records | Fine if fast enough | Fine if you stay careful | Strong |

“Internal” does **not** mean “a Python-only library is fine.” It means you may choose a denser format that **other languages can still read**.

### What this experiment cannot tell us

- Total service time (waiting in queues, the network, encryption)
- Whether an old reader understands a new field (that needs a separate test of the description file)
- Whether Go or Java would pick the same winner *(answered in the run below: they do not all pick the same answer)*
- Behaviour at tens of thousands of requests per second (pick a few libraries here, then load-test them)

### What we found (2026-08-16)

The same question was run in all nine languages. Times are **not** one contest across languages. We do not name a single winner. Groups for 1 record and for 100 records are separate.

On this tiny flat record, **leaving JSON is not one answer**. It depends on the language you ship.

| Language | Not clearly slower (1 record, in memory) | Small gap | Size of the fastest row | Ordinary JSON on that row? |
|----------|------------------------------------------|-----------|-------------------------|----------------------------|
| Python | `msgspec-msgpack` | `orjson` | 52 bytes (JSON 168) | `orjson` is close in time |
| Go | `protobuf` | — | 50 bytes (JSON 168) | No |
| Java | `protobuf` | — | 50 bytes (JSON 150) | No (at 100 records `jsoniter` is close in time) |
| JavaScript | `JSON.stringify` | — | 168 bytes | Yes — JSON is fastest |
| Rust | `prost` | — | 55 bytes (JSON 182) | No |
| C | `protobuf-c` | `protobuf-wire` | 51 bytes (JSON 170) | No. Both C protobuf rows use the suite wire path, not a generated Google pack. Official Google `protobuf` did not run. |
| C++ | `protobuf-wire` | — | 50 bytes (JSON 168) | No. Official `libprotobuf` did not run. At 100 records `msgpack` is not clearly slower. |
| C# | `SpanJson` | — | 157 bytes (protobuf 68) | Yes on time. C# has no MessagePack row in this suite. At 100 records both protobuf libraries are close in time. |
| Swift | `SwiftProtobuf` | — | 50 bytes (JSON 168) | No |

In Python, `orjson` is close to `msgspec-msgpack` at one record (about 1.79 µs versus 1.71 µs). Protocol Buffers is smaller (50 bytes versus 168) but slower than `orjson` on this sample. At 100 records, `orjson` is no longer close; MessagePack leads and Protocol Buffers is next. The plan said: if the gap is small on this tiny record, the format is not the bottleneck. For Python, that is the fair reading at N = 1.

In JavaScript and C#, ordinary JSON is still the fastest write-and-read on this sample. In Go, Java, Rust, C, C++, and Swift, a Protocol Buffers row is clearly fastest **and** about three times smaller than JSON.

That is **not** a reason to change a public web contract. It is a reason to decide per language, and only on a path you control.

**What this changes later:** Experiment 3 still asks what we pay to stay readable by other languages. In Python, compare `pickle` to `orjson` **and** to `msgspec-msgpack` / `protobuf` — the portable side is no longer “JSON only.” Experiment 10 (one record versus one hundred) already has a preview: some close-sets move when N grows. Do not skip it.

---

## Experiment 3 — What do we pay to stay readable by other languages?

**Status:** done for Python, Java, and Go (2026-08-16).  
**Folder:** [03-one-language-store](03-one-language-store/). Combined page: [results.md](03-one-language-store/results.md). Combined JSON: [results.json](03-one-language-store/results.json).  
**Sample:** Sample B, one record, saved as [03-one-language-store/sample.json](03-one-language-store/sample.json). Sample A was not run: one experiment file holds one sample kind.

### The question

> On the same samples, how much faster is a **Python-only** library than a library **another language can read**? Is that gain large enough to put the Python-only bytes in a store that another program might open later?

### Why these libraries exist

`pickle` (Python), `gob` (Go), Java’s built-in writer, **Kryo**, **Fory**, and **Hessian** store rich objects for **one language talking to itself**. They can store things JSON cannot (class identity, sometimes functions). They were not built for two languages to share.

Another language cannot read them. Several of them can run code while reading. That is a safety problem, not only a taste problem.

### Real situation

A session cache, a background-job body, or a store that “only we write today.” Next quarter a second service appears and cannot read the bytes. Or someone sends a hostile value and the reader runs it.

### Who we compare

| Language | Python-only (or Java-only, Go-only) | Other languages can read |
|----------|-------------------------------------|---------------------------|
| Python first | `pickle`, `cloudpickle`, `dill` | `orjson`, `msgspec-msgpack`, `protobuf` (what Experiment 2 left standing) |
| Later Java | Java’s built-in writer, `kryo`, `fory`, `hessian` | `jsoniter`, `protobuf` (what Experiments 1 and 2 left standing) |
| Later Go | `encoding/gob` | `goccy/go-json`, `protobuf` |

### How we decide

| If the Python-only library is… | Then… |
|--------------------------------|--------|
| Only about 1.2 to 1.5 times faster | Do **not** put it in a shared store. The gain does not pay for the lock-in or the safety story. |
| Many times faster **and** the store is one program, never shared, never exposed | Allowed only if you write that limit down |
| Faster but loses information, or the next language cannot read it | Reject |

### Costs and benefits

- A cache is not “just memory for us.” Another program, another language, or next year’s version of the same service may open the key.
- Several Python-only readers can execute code. A format other languages can read, plus a check at the door, is the careful default.
- A key that expires in five minutes can still be dangerous while it lives.

### What this experiment cannot tell us

- That `pickle` is safe (this program does not attack the reader)
- That Redis plus JSON is fast enough under load
- Whether a one-language library wins on Sample A (nested order) or on a value JSON cannot hold (a class, a function)

### What we found (2026-08-16)

On Sample B, the one-language libraries are **slower**, not faster. Times are not one contest across languages.

| Language | Fastest on this sample | One-language row | About how many times slower |
|----------|------------------------|------------------|-----------------------------|
| Python | `orjson` (1.70 µs, 168 bytes). `msgspec-msgpack` is close (1.86 µs, 52 bytes). | `pickle` 7.15 µs, 202 bytes. `cloudpickle` 15.5 µs. `dill` 57.2 µs. | `pickle` about **4×** |
| Java | `protobuf` (25.6 µs, 50 bytes) | `fory` 35.1 µs. `kryo` 42.1 µs (46 bytes, smallest). `java-serialization` 119 µs. | `java-serialization` about **4.5×** |
| Go | `protobuf` (1.10 µs, 50 bytes) | `encoding/gob` 14.6 µs, 173 bytes | about **13×** |

The plan said: if the one-language library is only a little faster, do not put it in a shared store. Here it is **not faster at all** on this record. There is no speed gain to trade for lock-in or for the safety story.

This sample has only ordinary fields. It is the “just pickle the cache” case. It is not the case those libraries were built for (a class, a function, or another value JSON cannot hold).

**What this changes later:** Experiment 4 still asks when JSON is too large for a growing sensor list. Do not treat a one-language library as the default “fast internal” choice on a small flat record.

---

## Experiment 4 — When is JSON too large for a sensor list?

**Status:** done for Rust (2026-08-16). C ran, but its sizes do not grow with the list, so C cannot answer the curve.  
**Folder:** [04-sensor-list-size](04-sensor-list-size/). Combined page: [results.md](04-sensor-list-size/results.md). Combined JSON: [results.json](04-sensor-list-size/results.json).  
**Sample:** Sample C, 8, 32, 128, then 512 numbers, saved as [04-sensor-list-size/sample.json](04-sensor-list-size/sample.json).

### The question

> As the list of numbers grows, when does JSON’s size (and write time) become more than a radio or a small device can afford?

### Why these libraries exist

**CBOR** was written so the **writer program itself** can be tiny, the message fairly small, and new types addable later without a special handshake. The authors said it is not a copy of MessagePack. MessagePack cares about message size and speed. CBOR also cares about how small the program in flash memory can be. It is the usual format for CoAP, a light cousin of HTTP on sensor networks.

**nanopb** is Protocol Buffers that fits a microcontroller. **QCBOR** and **zcbor** are CBOR for small devices. **postcard** is a compact Rust writer that works without a full operating system. **ArduinoJson** is JSON that tries not to break a small heap.

### Real situation

A device or a gateway sends sensor readings. The radio has a maximum packet size. Debug still matters (JSON is readable). When must we leave JSON?

### Who we compare

Start in **C** or **Rust**, where the device-side libraries live. Compare JSON, CBOR, MessagePack, and Protocol Buffers (or postcard) on the same growing list.

Python is only the cloud side, not the device.

**Be careful:** some C log names that say `nanopb` currently time a shared helper, not the full generated nanopb stack. Read the C page before you quote those names.

### What we look at first

**Size**, then write time. This is a **curve**, not one bar. The interesting moment is the list length at which JSON no longer fits the budget.

### How we decide

| If we see… | Then… |
|------------|--------|
| JSON still fits the radio budget at 512 numbers | Stay on JSON so people can read the packets |
| JSON overflows; CBOR or MessagePack still fit | Leave JSON on the device; you may keep JSON at the gateway |
| Only Protocol Buffers or postcard fits | Freeze the field list; accept the extra files and generators |

### Costs and benefits

- JSON is the friend of the person at 3 a.m. CBOR is the friend of the radio.
- MessagePack and CBOR stay flexible. Protocol Buffers stay small as the list grows **if** the field list is stable.
- On a microcontroller, the size of the **library in flash** can matter more than 40 extra bytes on the wire. This benchmark measures the message, not the flash image.

### What this experiment cannot tell us

- How many bytes the library occupies in flash
- Battery use
- Whether the radio already compresses the packet
- C on this machine (the C sizes do not grow with the list)

### What we found (2026-08-16)

We marked two example packet sizes: **128 bytes** and **512 bytes**. Your radio may differ. The curve we trust is **Rust**. C sizes stay near 320–670 bytes at every list length — that is not a growing list of numbers on the wire.

In Rust (in memory):

| Numbers | JSON (`serde_json` / `sonic-rs`) | postcard | prost | MessagePack / CBOR |
|---------|----------------------------------|----------|-------|--------------------|
| 8 | 234 B (over 128, under 512) | 91 B | 94 B | 135 B |
| 32 | 672 B (over 512) | 286 B | 290 B | 355–356 B |
| 128 | 2420 B | 1051 B | 1054 B | 1215–1216 B |
| 512 | 9415 B | 4128 B | 4131 B | 4677 B |

JSON already misses a 128-byte packet at 8 numbers. At 32 numbers it also misses a 512-byte packet. `postcard` and `prost` still fit 512 bytes at 32 numbers and miss it at 128. MessagePack and CBOR sit between JSON and postcard.

The plan said: if JSON overflows and a denser format still fits, leave JSON on the device. That is the Rust answer at 32 numbers on a 512-byte packet. At 128 numbers, nothing in this set fits 512 bytes.

**What this changes later:** Experiment 9 (size after gzip or zstd) is more useful now. Experiment 12 is still “format versus library.” Do not quote the C sizes as a device answer until the C runner writes the growing list.

---

## Experiment 5 — An event log: size and write time only

**Status:** done for Python, Java, and Go (2026-08-17).  
**Folder:** [05-event-log-formats](05-event-log-formats/). Combined page: [results.md](05-event-log-formats/results.md). Combined JSON: [results.json](05-event-log-formats/results.json).  
**Sample:** Sample D, one record and 100 records, saved as [05-event-log-formats/sample.json](05-event-log-formats/sample.json).

### The question

> For Sample D, how do Avro, Protocol Buffers, and JSON compare on size and write time — enough to plan disks and producer CPU?

### Why these formats exist

**Avro** was built so old and new software can run together without regenerating code in every language. The field description can travel with the data, or sit in a service that accepts or rejects a change. Kafka plus that kind of service is this world.

**Protocol Buffers** on an event log is the other world: field numbers, a shared file, and automatic checks that refuse a breaking change.

JSON events are easy to read. They drift unless someone writes a process.

### Real situation

A fact such as “order placed” on a durable log. Many writers, many readers, months of storage. Outside parties should receive **JSON at the edge**, not be forced to speak the internal format.

### Who we compare

| Language | Avro | Protocol Buffers | JSON |
|----------|------|------------------|------|
| Java | `avro` | `protobuf` | `jackson` |
| Go | `hamba/avro`, `linkedin/goavro` | `protobuf` | `sonic` or `encoding/json` |
| Python | `avro` | `protobuf` | `orjson` |

Go has two Avro libraries: one binds to structs; one uses maps and comes from the Kafka world. That is a useful extra comparison.

### How we decide

This experiment **plans disks and CPU** for a format you already chose because of compatibility. Speed cannot override a failed compatibility story.

| If we see… | Then… |
|------------|--------|
| JSON size is acceptable for the months you keep the log | JSON events are allowed *if* you also write down how fields may change |
| Avro or Protocol Buffers cut size a lot | Use that saving in the disk budget. Still pick Avro vs Protocol Buffers on process grounds (who may add a field, and when). |
| Write time dominates the producer’s CPU | Pick the faster library **inside** the format you already chose |

### Costs and benefits

- “We use Avro” without a rule for accepted changes is not a plan. “We use Protocol Buffers” without a rule for field numbers is not a plan.
- Do **not** treat the event format as the analytics store. Column files such as Parquet are a different job. This suite does not measure them.
- Do not let each team pick a different format. The set of systems will fall apart.

### What this experiment cannot tell us

- Whether an old reader can read a new field
- How far the log reader falls behind
- Whether two languages write the exact same bytes (each language has its own runner)

### What we found (2026-08-17)

On Sample D, Avro and Protocol Buffers write about **half** the bytes of JSON (about 105 and 123 versus 257). Times are not one contest.

| Language | Not clearly slower (1 record) | Size of that row | At 100 records |
|----------|-------------------------------|------------------|----------------|
| Python | `orjson` (2.78 µs, 257 B) | JSON | `protobuf` leads; Avro is much slower |
| Java | `protobuf` (48.5 µs, 123 B) | protobuf | still `protobuf` |
| Go | `hamba/avro` (2.08 µs, 107 B) | Avro | still `hamba/avro`; `linkedin/goavro` is slower |

Use the size cut in the disk budget. Still pick Avro vs Protocol Buffers on process grounds. Inside Avro, Go’s two libraries are not the same speed.

---

## Experiment 6 — Document databases: BSON, Smile, Ion

**Status:** done for Java, JavaScript, Go, Rust, and C (2026-08-17).  
**Folder:** [06-document-db-formats](06-document-db-formats/). Combined page: [results.md](06-document-db-formats/results.md). Combined JSON: [results.json](06-document-db-formats/results.json).  
**Sample:** Sample A, one record, saved as [06-document-db-formats/sample.json](06-document-db-formats/sample.json).

### The question

> On Sample A, do BSON, Smile, and Ion win a write-and-read contest against JSON and MessagePack — or do they **lose**, because they spend bytes on the ability to skip fields?

### Why these formats exist

**BSON** (MongoDB) stores JSON-like records with type tags and **lengths**, so a reader can skip a field without parsing it. It also adds types JSON lacks (a date, raw binary). It was not built to win “write this whole record and read it all back.”

**Smile** (used with Jackson and Elasticsearch) is JSON-like values as bytes, with care for a **sequence** of records.

**Ion** (Amazon) is a typed document format (decimals, timestamps, shared names).

### Real situation

A program talking to MongoDB, or Java services talking to Elasticsearch in Smile. The question is not “should we use BSON between two ordinary services?”

### Who we compare

Java is the natural home: `jackson` (JSON), `jackson-cbor`, `jackson-smile`, `ion`, `bson`, `msgpack`. BSON also exists in Python, JavaScript, Go, C, and Rust.

This experiment can share a run with Experiment 12 on Java.

### How we decide

| If we see… | Then… |
|------------|--------|
| BSON is slower or larger than MessagePack on a full write-and-read | Do **not** pick BSON for an ordinary service call. Keep it for Mongo. |
| Smile beats Jackson JSON by a lot, and every other service already uses Jackson | Smile is a fair format **inside that group of services**, not on a public website |
| Sizes are close after gzip | The extra skip information may not be worth it unless you actually skip |

### Costs and benefits

- This benchmark always writes and reads the **whole** sample. The product win of BSON (skip a large field on disk) is only partly visible.
- Using the database’s format on the network copies a storage decision into a network decision.

### What this experiment cannot tell us

- Time to skip one field in a large stored record
- MongoDB disk layout or Elasticsearch index cost

### What we found (2026-08-17)

BSON **loses** a full write-and-read. It is larger and slower than MessagePack in Java, JavaScript, Go, Rust, and C (517–577 bytes versus 317–397). Keep BSON for Mongo.

In Java, Smile is not clearly slower than Jackson JSON and is smaller (233 vs 440). Ion is slowest. Smile is a fair format inside a Jackson group of services, not on a public website.

---

## Experiment 7 — Write once, read many times

**Status:** done for C++, C#, JavaScript, Python, and Rust (2026-08-17).  
**Folder:** [07-write-once-read-many](07-write-once-read-many/). Combined page: [results.md](07-write-once-read-many/results.md). Combined JSON: [results.json](07-write-once-read-many/results.json).  
**Sample:** Sample A and Sample C (512 numbers), saved as [07-write-once-read-many/sample.json](07-write-once-read-many/sample.json).

### The question

> For a record we **build once** and **read many times**, how do FlatBuffers and Cap’n Proto split write time and read time, compared with Protocol Buffers?

### Why these libraries exist

**FlatBuffers** (Google, for games): read a field from the received bytes without building a full object. A game frame cannot afford to parse every packet into objects.

**Cap’n Proto** (Kenton Varda, after Protocol Buffers v2): turning a value into bytes was itself too slow, so the written layout *is* the layout in memory. “Infinitely faster to write” means “there is no separate write step,” not “physics stopped.”

**rkyv** (Rust): the same idea, Rust only, no description file. You can map a file into memory and treat it as structures.

**FlexBuffers**: FlatBuffers-like, when you do not know the shape at compile time.

**MemoryPack**, **ZeroFormatter**, **FlatSharp** (.NET): fewer new objects, or read in place, on one runtime.

### Real situation

A game asset, a replay file, a file mapped into memory, or a C++ planner sending a buffer that a Java program will read — sometimes only *some* fields.

### Who we compare

| Language | Libraries | Caution |
|----------|-----------|---------|
| C++ | `flatbuffers`, `capnproto`, `flexbuffers`, `protobuf` | Best place to ask this question |
| C# | `FlatSharp`, `ZeroFormatter`, `MemoryPack`, `ProtoBuf` | — |
| JavaScript | `flatbuffers`, `flexbuffers` | — |
| Python | `flatbuffers`, `protobuf` | Python FlatBuffers **write** uses a slow Python builder. Do not reject the *format* from that row. |
| Rust | `rkyv`, `prost` | The timed `rkyv` **read builds a full value** so we can check information. The product win (read without building) is **not** what the clock measures. |

### How we decide

Look at **write time and read time separately**. Do not add them. The whole point is that writing and reading are different jobs.

| If we see… | Then… |
|------------|--------|
| Read is much cheaper than Protocol Buffers; write is more expensive | Good when you write once and read many times, or read two fields of a large record |
| Write is expensive and you change the record on every request | Prefer Protocol Buffers. Changing lengths in place is awkward. |
| Python FlatBuffers write looks terrible | That is the Python builder. Repeat in C++ before you decide. |

### Costs and benefits

- You still pay to **build** the layout.
- The win appears when you do **not** turn every field into a language object. Our “same information?” check may force more work than a real reader (especially `rkyv`).
- An unchecked buffer of offsets is a safety problem. “No parse” must not mean “no bounds check.”
- A hex dump is worse than a JSON log. You need tools that understand the format.

### What this experiment cannot tell us

- Time to touch two fields only (we do not ship that clock yet)
- Safety of an unchecked buffer

### What we found (2026-08-17)

Look at write and read separately.

In **C++** on Sample A, FlatBuffers writes fastest (0.60 µs); Cap’n Proto **reads** fastest (0.52 µs). On Sample C (512 numbers), Cap’n Proto is fastest overall; protobuf-wire **write** jumps to 11.7 µs while Cap’n Proto write stays about 1 µs. Python FlatBuffers write is terrible (90 µs vs protobuf 2.55 µs) — that is the Python builder. In Rust, `rkyv` is faster than `prost` on both write and read; the timed read still builds a full value.

---

## Experiment 8 — Files people edit are not a request path

**Status:** done for Go, Swift, and C# (2026-08-17).  
**Folder:** [08-human-files](08-human-files/). Combined page: [results.md](08-human-files/results.md). Combined JSON: [results.json](08-human-files/results.json).  
**Sample:** Sample A and Sample E, saved as [08-human-files/sample.json](08-human-files/sample.json).

### The question

> On the same records, how much slower and larger are YAML, TOML, and XML than JSON? Large enough that they must stay **files people edit**, not the format of a live request?

### Why these formats exist

YAML, TOML, XML, and property lists exist so **people can edit documents**. They were not built to win a live-request contest.

### Real situation

A service reads a config file at start, then serves JSON or binary on the live path. Someone proposes “we already have YAML, let’s send that on the wire.”

### Who we compare

- Go: `goccy/go-yaml`, `pelletier/go-toml` versus a JSON library
- Swift: `Yams`, `TOML`, `XMLCoder` versus a JSON library
- C#: `YamlDotNet`, `MS XmlSerializer` versus `System.Text.Json`

### How we decide

If YAML or XML is several times slower or much larger than JSON, it stays a **file**. Convert to JSON or Protocol Buffers **once**, when the process starts.

### Costs and benefits

- The right answer is often both: YAML on disk, a compact format in memory and on the network.
- Some TOML libraries cannot use a bare list as the root. The suite wraps a batch as a table. That is a limit of TOML, not a timing trick.

### What this experiment cannot tell us

- Whether your operators prefer YAML in the editor (that is a people question)

### What we found (2026-08-17)

YAML and XML are several times slower than JSON. They stay **files**. Convert once at start.

On Sample A: Go YAML is about 38× slower than `goccy/go-json` (201 µs vs 5.3 µs). Swift YAML and XML are about 8× slower than `IkigaJSON`. C# `YamlDotNet` is about 9× slower than `System.Text.Json`. TOML is closer (Go about 4×; Swift about 4×) and a bit larger. XML is much larger (C# 1258 vs 588 bytes).

---

## Experiment 9 — “Just turn compression on”

**Status:** planned.  
**Sample:** Sample E (repeated words), Sample C (numbers), Sample B (tiny record).

### The question

> After **gzip** or **zstd**, does JSON stay larger than a dense binary format — or does squeezing the bytes erase the reason to leave JSON?

### Why this is its own experiment

gzip and zstd find **repeated patterns** in any bytes. Protocol Buffers and MessagePack already drop field *names*. gzip finds a different kind of repetition (repeated words, repeated digits).

Teams often turn gzip on for everything. Large pages get smaller. Tiny control messages get **slower**, because the processor work exceeds the bytes you save.

### Real situation

A bandwidth ticket. Public HTTP may already compress. Chatty internal calls on a fast local network may not want a compressor on every message.

### What we already know

The runner can record **size after gzip** and **size after zstd** once per sample. Experiment 1: named JSON went from 448 bytes to 229 bytes after gzip.

### What we expect

| Sample | What we expect |
|--------|----------------|
| Sample E (repeated words) | gzip will pull JSON toward binary |
| Sample C (numbers) | A dense format will keep an edge: numbers are already compact |
| Sample B (tiny) | Compression is processor work for almost no saving |

### How we decide

| If we see… | Then… |
|------------|--------|
| gzip makes JSON almost as small as Protocol Buffers on Sample E | Do not leave JSON *for size* on text-heavy bodies; use HTTP compression |
| The gap survives on Sample C | The format still matters for numbers |
| Tiny Sample B shrinks by a few bytes and costs time | Do not compress chatty control calls |

### Costs and benefits

- On a local network, processor time often matters more than bytes. On a long-distance link or in cold storage, bytes often matter more.
- Do not compress images and video again. They are already compressed.
- Do not compare this suite’s raw size to a production capture that already went through gzip, unless this experiment says so.

### What this experiment cannot tell us

- How long compression itself takes (we record **size**, once, not compress time)
- How encryption and HTTP/2 stack with the compressor

---

## Experiment 10 — One record versus one hundred

**Status:** planned.  
**Sample:** Sample B and Sample D, once with 1 record and once with 100 records in the same write.

### The question

> Does the library that wins at **one** record still win at **one hundred** records in a single write?

### Why this matters

A remote call is usually **one** body. A log shipper or a telemetry exporter often writes **many** records at once. Some libraries have a large cost every time you call them. That cost vanishes when the batch is large. Some do not.

The project already measures 1 and 100. This experiment is how we **read** those two columns.

### How we decide

| If we see… | Then… |
|------------|--------|
| Winner at 1 loses at 100 | You were measuring the cost of calling the library, not the cost of writing the data. Quote the number of records that matches the product. |
| Size grows in a straight line, time does not | Setup is being spread over many records. Reusing writers (which this suite already does outside the clock) is the lesson. |
| Ranks stay put | You may quote either number without changing the story. |

### Costs and benefits

- A chart of 100 records is not evidence for a one-record call.
- Wrapping many records in one Protocol Buffers message is part of the job, not an extra.

### What this experiment cannot tell us

- The best batch size for *your* log system (try several sizes in a load test)

---

## Experiment 11 — Writing into memory versus writing as if to a file

**Status:** planned.  
**Sample:** Sample A or Sample B.

### The question

> When the product writes to a **file or socket**, which libraries really write as they go, and does that change the ranking we saw in memory?

### Why this matters

Caches use a block of bytes. Files and sockets use a stream. Many published “stream” numbers are misleading: the library built the full result and then copied it.

We label each stream row:

| Label | Meaning |
|-------|---------|
| **real** | Both write and read use the library’s stream functions |
| **text on a stream** | A text writer attached to a stream (common for JSON) |
| **copied** | Full result in memory, then dump or load |

### Who we compare

| Language | What the labels say |
|----------|---------------------|
| Go, Java, C++, many C# libraries | Often **real** — best place to ask this |
| JavaScript | Memory only (no second path claimed) |
| C, Swift | Stream rows are **copied** — do not use them as stream evidence |

C# extra: the in-memory path for *binary* libraries is often **Base64 text** of the real bytes (letters and digits that represent the bytes). That extra step is real if you store binary as text.

### How we decide

Only treat **real** rows as evidence for a file or socket. If the product is a cache, the in-memory column is the one that matters. If **copied** time is almost the same as in-memory time, write that down and stop claiming a stream win.

### Costs and benefits

- “Stream” does not mean “large,” and “in memory” does not mean “small.”
- A copied stream that matches in-memory is not a scandal. Claiming it as writing-as-you-go is.

### What this experiment cannot tell us

- Reading a multi-gigabyte file a little at a time (our samples are small)
- How the operating system treats a real socket

---

## Experiment 12 — Is the difference the format, or the library?

**Status:** done for Java, C++, Go, C#, and JavaScript (2026-08-17, [PR #89](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/89)).  
**Folder:** [12-format-vs-library](12-format-vs-library/). Combined page: [results.md](12-format-vs-library/results.md). Combined JSON: [results.json](12-format-vs-library/results.json).  
**Sample:** Sample A, one record, saved as [12-format-vs-library/sample.json](12-format-vs-library/sample.json).

### The question

> If **one** library can write several formats, how much of the speed and size difference is the **format**, and how much is **that library**?

### Why this experiment exists

People say “we use JSON” or “we switched to binary” as if the name were the whole decision. On any language page, several libraries share a format name and still differ a lot.

The cleanest way to separate format from library is to **hold the library still** and only change what it writes:

| One library | Formats it can write in this project |
|-------------|--------------------------------------|
| **Jackson** (Java) | JSON, CBOR, Smile, Ion, MessagePack |
| **nlohmann** (C++) | JSON, CBOR, BSON, MessagePack, UBJSON |
| **ugorji** (Go) | JSON, MessagePack, CBOR |

That is useful because the difference we see is more likely to come from the format, not from two different authors. It is also a limit: the result is about **that one library**, not about every MessagePack library in the world.

Smaller versions of the same idea:

- C#: Bond Compact vs Bond Fast vs Protocol Buffers — one description of the fields, two Microsoft layouts (smaller file vs faster read) plus Google’s format
- JavaScript: three Protocol Buffers libraries
- Go: three MessagePack libraries
- Go JSON: several JSON libraries (a cousin of Experiment 1)

### Real situation

A design review that is about to require “binary” without naming the library. Or a paper that wants to talk about formats rather than brands.

### How we decide

| If we see… | Then… |
|------------|--------|
| Jackson JSON and Jackson MessagePack are close, but Jackson JSON and Gson are far apart | The **library** matters more than the **format**. “Move to binary” without picking a library is not a plan. |
| All Jackson binary formats beat Jackson JSON by a similar factor | The **format** has a real effect inside that library |
| Bond Fast reads faster than Bond Compact and writes a larger file | That is the trade Microsoft documented. Pick the layout on purpose. |

### Costs and benefits

- Holding Jackson still is fair for “JSON versus MessagePack **in Jackson**.” It is not a claim about MessagePack in Python.
- Two libraries can share a format name and differ by a large factor. Experiment 1 already showed this inside JSON.

### What this experiment cannot tell us

- A world ranking of formats across languages
- Whether your team already knows Jackson (knowing Jackson is not the same as knowing nlohmann)

### What we found (2026-08-17)

The same question was run in Java, C++, Go, C#, and JavaScript. Times are **not** one contest across languages. We do not name a single winner.

On this one order, the **library** often moves time more than the **format** does.

| Language | Not clearly slower (in memory) | What that means here |
|----------|--------------------------------|----------------------|
| Java | `jsoniter` (about 49 µs, 440 bytes) | Same JSON size as Jackson and Gson. Jackson JSON is about 110 µs. Inside Jackson, Smile is smaller (233 bytes) and similar in time to Jackson JSON. Jackson MessagePack is slower than Jackson JSON. Ion is slowest. |
| C++ | `nlohmann_json` (about 9.07 µs, 458 bytes) | All five nlohmann formats sit in a tight time band (about 9–10 µs). MessagePack and CBOR are smaller. BSON is **larger** than JSON. |
| Go | `goccy/go-json` (about 2.89 µs, 448 bytes) | Inside ugorji, MessagePack is a bit faster and smaller than JSON. `encoding/json` is about three times slower than `goccy/go-json`. The three MessagePack libraries are closer to each other than the three JSON libraries are. |
| C# | `MS Bond Fast` (about 10.3 µs, 376 bytes) | Bond Compact is smaller (208 bytes) and a little slower. Both protobuf libraries write 208 bytes and are slower than Bond. Fast vs Compact is the size trade Microsoft wrote down. |
| JavaScript | `google-protobuf` (about 16 µs, 155 bytes) | `protobufjs` about 39 µs. `protobuf-es` about 69 µs. Same 155 bytes. Same format, about four times the time. |

The plan said: if Jackson JSON and Jackson MessagePack are close, but Jackson JSON and Gson are far apart, the **library** matters more than the **format**. Here Jackson JSON and Jackson MessagePack are in the same time neighbourhood (MessagePack is a bit slower). `jsoniter` is about twice as fast as Jackson, same size. “Move to binary” without naming the library is not a plan.

**What this changes later:** Experiment 6 still asks whether BSON, Smile, and Ion win a full write-and-read because they spend bytes on skip-ability. We already know Jackson Smile is smaller, not clearly faster, and nlohmann BSON is larger than nlohmann JSON. Experiment 13 is still next: do these ranks stay put if we change the sample?

---

## Experiment 13 — Is the ranking an accident?

**Status:** done for all nine languages (2026-08-17, [PR #90](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/90)). This is the researcher’s experiment. Builders should still read the conclusion.  
**Folder:** [13-ranking-accident](13-ranking-accident/). Combined page: [results.md](13-ranking-accident/results.md). Combined JSON: [results.json](13-ranking-accident/results.json).  
**Sample:** Samples A–E, 1 and 100 records, saved as [13-ranking-accident/sample.json](13-ranking-accident/sample.json).

### The question

> Do the ranks from Experiment 1 (and later 2) **stay the same** if we change the sample, the number of records per write, or the cleaning rule?

### Why this experiment exists

One run on one computer is a single evening’s measurement. Other programs, heat, and rare stalls can move a close contest. A ranking that flips when we change how we set aside stalls was never a fact about the libraries. It was a fact about the cleaning rule.

### What we change (one thing at a time)

| What we change | What a flip would mean |
|----------------|------------------------|
| Sample A vs B vs C vs D vs E | The winner depends on the data. Never quote a rank without naming the sample. |
| 1 record vs 100 | Same lesson as Experiment 10 |
| Keep every trial after warm-up; drop more stalls; drop fewer; clip extremes instead of dropping | Close contests are fragile. Distant contests are not. |
| The first trial vs the rest | The first request after start (for example a cold function) cares about the first trial. A long-running service does not. |
| Shuffled order vs a fixed order | Heat or cache was helping whoever ran first. |
| Three full runs on the same machine | A rank that holds three times is stronger than a rank that holds once. |
| Two versions of the same library | Did *this* library get better, or did the machine have a good day? |

### How we decide

- If **orjson** still beats **json** by a large factor on every sample and every cleaning rule, Experiment 1 is a stable fact about named JSON in Python.
- If two libraries swap places when we change the stall rule, we will not name a winner. We will say the contest is too close for this sample.
- If the winner on Sample E is not the winner on Sample C, we will write that down and stop using one chart for every job.

### Costs and benefits

- More trials and more sessions cost machine time. That is the price of a sentence that begins with “we found” rather than “on this evening we saw.”
- A number without the cleaning rule is an incomplete sentence.

### What this experiment cannot tell us

- Behaviour on a different processor until we repeat it there
- A world ranking across languages (we will never treat that as a result)
- Shuffled order versus a fixed order (the runner always shuffles blocks)
- Three separate evenings on this machine
- Two versions of the same library (we did not pin an old package)

### What we found (2026-08-17)

Named JSON, all nine languages, Samples A–E, 1 and 100 records, in memory.

**Python is stable.** `orjson` is first on every sample and at both 1 and 100. On Sample A it is about **5.3 times** faster than `json`. That ratio stays put under IQR 1.5, IQR 3.0, no stall filter, and keeping the first trial. Experiment 1 is a fact about named JSON in Python on this machine.

**Some languages keep one name at N = 1:** JavaScript (`JSON.stringify`), C (`yyjson`), Rust (`sonic-rs`), Swift (`IkigaJSON`).

**Some languages flip when the sample changes:** Go (`goccy/go-json` / `segmentio/encoding/json` / `sonic`), Java (`jsoniter` on A–C, `dsl-json` on D–E), C++ (`simdjson` / `yyjson` / `nlohmann_json`), C# (`SpanJson`, except `NetJSON` on the sensor list).

**1 vs 100 flips** in Go, Swift, and some Java / Rust / C++ / C# cells. Python, JavaScript, and C do not flip.

Never quote a rank without naming the sample and N. A close contest (Go on Sample A) is not the same kind of fact as `orjson` versus `json`.

---

## What this laboratory cannot measure

These are real questions. We do not pretend to answer them here.

| Question | Why not here | Where to measure it |
|----------|--------------|---------------------|
| Can an old reader understand a new field? | One frozen description per run | A separate test of the description file |
| Can hostile bytes take over the process? | We do not send attacks | A security review |
| Time at 50,000 requests per second | One thread, no network | A load test, after we pick a few libraries here |
| Touch two fields without building the rest | The clock still builds a value so we can check information | A custom test; especially for `rkyv` and FlatBuffers |
| Scanning a data lake (Parquet, ORC) | This suite writes whole records, not columns | A lake test |
| The exact same bytes in two languages | Each language has its own runner | A cross-language check of Protocol Buffers |
| How long gzip itself takes | We record compressed **size**, once, not compress time | A later test |

---

## How an experiment is filed

```text
experiments/
  PLAN.md
  samples/
  01-json-library-bakeoff/
    README.md
    experiment.yaml          ← the one file to edit
    run.yaml                 ← written from experiment.yaml for the runner
    sample.json              ← shared record
    summarize.py             ← local CSV → results.json and results.md
    results.md               ← every language, one page to read
    results.json             ← every language, for a dashboard
    run.sh                   ← one language or all
    python/ go/ java/ …      ← results.md, results.json (logs stay local)
```

When we open a new experiment we:

1. Write `experiment.yaml` (copy Experiment 1’s file and change it).
2. Save `sample.json` from that file.
3. Add language folders and a `run.sh`.
4. Write `summarize.py` so a dashboard can load `results.json`.
5. Measure, then add an **After Experiment *n*** block below. Do not commit `<lang>/logs/`.

Do not compare write times between language folders. Size is the only number that is roughly fair across languages, and only when both sides write the same field description.

---

## After Experiment 1

- **Date:** 2026-08-16
- **Sample:** [01-json-library-bakeoff/sample.json](01-json-library-bakeoff/sample.json) (Sample A)
- **Folder:** [01-json-library-bakeoff](01-json-library-bakeoff/) · [combined page](01-json-library-bakeoff/results.md) · [combined JSON](01-json-library-bakeoff/results.json)
- **Finding:** The same question was run in all nine languages. Combined file: [results.json](01-json-library-bakeoff/results.json). Times are **not** one contest across languages. We do not name a single winner: this sample is one small order, and a different record can change who is first. Instead we group libraries by how often they are slower than the fastest named-JSON library on this sample (`top_group` in the JSON). On this particular order the gap was large in most languages, so the “not clearly slower” set has one name. Go is the exception: `segmentio/encoding/json` and `sonic` sit in the small-gap (“close”) set. Inside each language the reference (lowest middle time) was:

| Language | Fastest named-JSON library (in memory) |
|----------|----------------------------------------|
| Python | `orjson` |
| Go | `goccy/go-json` |
| Java | `jsoniter` |
| JavaScript | `JSON.stringify` |
| Rust | `sonic-rs` |
| C | `yyjson` |
| C++ | `simdjson` (fast read; write is prepared text) |
| C# | `SpanJson` |
| Swift | `IkigaJSON` |

On Sample A in Python, `json` took about 22 microseconds to write and read. `orjson` took about 4 microseconds — about five and a half times less — and wrote the same named JSON (448 bytes; 229 after gzip). `pydantic` was slower than `json` when reading, because it also checks types. `msgspec` was almost as fast as `orjson` but wrote only 192 bytes: a list of values, not named fields. For a public Python service that must send ordinary named JSON, **`orjson` is the fair winner**. Changing the JSON library is enough to gain a large speed-up. We have not yet earned the right to change the format.
- **What this changes about Experiment 2:** Compare MessagePack and Protocol Buffers to ordinary named JSON (`orjson`, with `json` as the familiar starting point). Do not use `msgspec` as the JSON side.
- **What this does not answer:** Other samples; many records in one write; other languages; the network; whether binary is worth a new shared description of the fields.

---

## After Experiment 2

- **Date:** 2026-08-16
- **PR:** [#84](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/84)
- **Sample:** [02-flat-record-formats/sample.json](02-flat-record-formats/sample.json) (Sample B, 1 and 100 records)
- **Folder:** [02-flat-record-formats](02-flat-record-formats/) · [combined page](02-flat-record-formats/results.md) · [combined JSON](02-flat-record-formats/results.json)
- **Finding:** The same question was run in all nine languages. Times are **not** one contest across languages. We do not name a single winner. On this tiny flat record, leaving JSON is **language-specific**. In Python, `orjson` is close to `msgspec-msgpack` at one record (about 1.79 µs versus 1.71 µs; 168 bytes versus 52). Protocol Buffers is smallest (50 bytes) but slower than `orjson` here. At 100 records, `orjson` is no longer close. In JavaScript, `JSON.stringify` is fastest. In C#, `SpanJson` is fastest; both protobuf libraries sit on the size front and become close in time at 100 records (C# has no MessagePack in this suite). In Go, Java, Rust, C, C++, and Swift, a Protocol Buffers row is clearly fastest and about three times smaller than JSON. C and C++ must be read with care: C `protobuf-c` uses the suite wire path, not a generated Google pack; official Google `libprotobuf` did not run in C or C++. A small gap on this record is not a reason to change a public contract.
- **What this changes about Experiment 3:** On the portable side, use `orjson` **and** the Experiment 2 MessagePack / Protocol Buffers names (`msgspec-msgpack`, `protobuf`). Do not treat “leave JSON” as already decided for Python.
- **What this changes about Experiment 10:** We already saw some groups move when N goes from 1 to 100 (Python `orjson` drops out of the close set; Java `jsoniter` and C# protobuf enter it; C++ `msgpack` becomes similar). Keep the experiment; this is only a preview on Sample B.
- **What this does not answer:** Total service time; whether an old reader understands a new field; load at tens of thousands of requests per second; official Google protobuf in C and C++ on this machine.

---

## After Experiment 3

- **Date:** 2026-08-16
- **PR:** [#85](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/85)
- **Sample:** [03-one-language-store/sample.json](03-one-language-store/sample.json) (Sample B, one record)
- **Folder:** [03-one-language-store](03-one-language-store/) · [combined page](03-one-language-store/results.md) · [combined JSON](03-one-language-store/results.json)
- **Finding:** On this tiny flat record, one-language libraries are **slower**, not faster, than a library another language can read. In Python, `orjson` is fastest (about 1.70 µs); `msgspec-msgpack` is close and smaller; `pickle` is about four times slower and larger (7.15 µs, 202 bytes). `cloudpickle` and `dill` are slower still. In Java, `protobuf` is fastest; `kryo` is a little smaller but slower; `java-serialization` is about four and a half times slower. In Go, `protobuf` is fastest; `encoding/gob` is about thirteen times slower. There is no speed gain here to trade for lock-in. The sample has only ordinary fields — the common “just pickle the cache” case, not a class or a function.
- **What this changes about Experiment 4:** Nothing about the sensor-list question. Do not treat a one-language library as the fast internal default on a small flat record.
- **What this does not answer:** Safety of `pickle` (this program does not attack the reader); Redis plus JSON under load; Sample A; a value that JSON cannot hold.

---

## After Experiment 4

- **Date:** 2026-08-16
- **PR:** [#87](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/87)
- **Sample:** [04-sensor-list-size/sample.json](04-sensor-list-size/sample.json) (Sample C, 8 / 32 / 128 / 512 numbers)
- **Folder:** [04-sensor-list-size](04-sensor-list-size/) · [combined page](04-sensor-list-size/results.md) · [combined JSON](04-sensor-list-size/results.json)
- **Finding:** Trust the Rust size curve. C sizes do not grow with the list, so C cannot answer this question here. In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte packet) and 672 bytes at 32 numbers (over a 512-byte packet). `postcard` and `prost` are about half that and still fit 512 bytes at 32 numbers (about 286–290 bytes); they overflow at 128 numbers (about 1051 bytes). MessagePack and CBOR sit in between. At 128 numbers, nothing in this set fits a 512-byte packet.
- **What this changes about Experiment 9:** Size after gzip or zstd is now the next size question. Uncompressed JSON is already too large for these example packets at 32 numbers.
- **What this does not answer:** Flash size of the library; battery; whether the radio compresses the packet; C on this machine.

---

## After Experiment 12

- **Date:** 2026-08-17
- **PR:** [#89](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/89)
- **Sample:** [12-format-vs-library/sample.json](12-format-vs-library/sample.json) (Sample A, one record)
- **Folder:** [12-format-vs-library](12-format-vs-library/) · [combined page](12-format-vs-library/results.md) · [combined JSON](12-format-vs-library/results.json)
- **Finding:** On this one order, the library often moves time more than the format does. In Java, `jsoniter` is not clearly slower (about 49 µs, 440 bytes). Jackson JSON is about 110 µs and the same size. Inside Jackson, Smile is smaller (233 bytes) and similar in time; MessagePack is slower than Jackson JSON; Ion is slowest. `gson` sits between `jsoniter` and Jackson. In C++, all five nlohmann formats sit in a tight time band (about 9–10 µs); JSON is fastest; BSON is larger than JSON. In Go, `goccy/go-json` is fastest; inside ugorji, MessagePack is a bit faster and smaller than JSON; `encoding/json` is about three times slower than `goccy/go-json`. In C#, Bond Fast is fastest and larger (376 bytes); Bond Compact is smaller (208 bytes); both protobuf libraries write 208 bytes and are slower than Bond. In JavaScript, three Protocol Buffers libraries write 155 bytes and differ by about four times (`google-protobuf` about 16 µs, `protobuf-es` about 69 µs). “Move to binary” without naming the library is not a plan.
- **What this changes about Experiment 6:** The document-database question still stands (skip a field). We already know Jackson Smile is smaller, not clearly faster, and nlohmann BSON is larger than nlohmann JSON on a full write-and-read.
- **What this changes about Experiment 13:** Still the next first-wave item. A rank that is a library gap (Java `jsoniter` vs Jackson; JavaScript protobuf trio) is the kind of gap we should see again if the ranking is real.
- **What this does not answer:** A world ranking of formats; whether your team already knows Jackson; time to skip one field; Experiment 11’s extra C# in-memory step for binary.

---

## After Experiment 13

- **Date:** 2026-08-17
- **PR:** [#90](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/90)
- **Sample:** [13-ranking-accident/sample.json](13-ranking-accident/sample.json) (A–E, 1 and 100 records)
- **Folder:** [13-ranking-accident](13-ranking-accident/) · [combined page](13-ranking-accident/results.md) · [combined JSON](13-ranking-accident/results.json)
- **Finding:** Python `orjson` stays first on every sample and both N; about 5.3× faster than `json` on Sample A under every stall rule we tried. JavaScript, C, Rust, and Swift keep one first place at N = 1. Go, Java, C++, and C# flip when the sample changes. 1 vs 100 flips in Go, Swift, and some other cells. Quote the sample and N.
- **What this changes about Experiment 10:** We already have the 1-vs-100 named-JSON preview. Experiment 10 should still ask the same question for mixed formats (JSON / MessagePack / Protocol Buffers), not only JSON.
- **What this does not answer:** Another processor; shuffled vs fixed order; three evenings; two library versions.

---

## After Experiment 5

- **Date:** 2026-08-17
- **Sample:** [05-event-log-formats/sample.json](05-event-log-formats/sample.json) (Sample D, 1 and 100)
- **Folder:** [05-event-log-formats](05-event-log-formats/) · [combined page](05-event-log-formats/results.md) · [combined JSON](05-event-log-formats/results.json)
- **Finding:** Avro and Protocol Buffers are about half the bytes of JSON on this event. In Python, `orjson` is fastest at N = 1; Avro is smallest and much slower. At N = 100, Protocol Buffers leads. In Java, `protobuf` is fastest at both N. In Go, `hamba/avro` is fastest at both N; the other Avro library is slower. Use the size cut in the disk budget. Still pick the format on process grounds.
- **What this changes about Experiment 10:** The 1-vs-100 flip is real for Python on this event (`orjson` → `protobuf`). Keep Experiment 10.
- **What this does not answer:** Old reader vs new field; lag of the log reader; same bytes in two languages; C# / Rust / JS Avro rows (not in this run).

---

## After Experiment 6

- **Date:** 2026-08-17
- **Sample:** [06-document-db-formats/sample.json](06-document-db-formats/sample.json) (Sample A)
- **Folder:** [06-document-db-formats](06-document-db-formats/) · [combined page](06-document-db-formats/results.md)
- **Finding:** BSON is larger and slower than MessagePack on a full write-and-read. Do not pick it for an ordinary service call. Jackson Smile is smaller than Jackson JSON and similar in time. Ion is slowest.
- **What this does not answer:** Time to skip one field; Mongo disk layout; Python and C# BSON (not in the suite).

---

## After Experiment 7

- **Date:** 2026-08-17
- **Folder:** [07-write-once-read-many](07-write-once-read-many/)
- **Finding:** In C++, Cap’n Proto reads cheaper than FlatBuffers on Sample A; on a 512-number list, protobuf write is much more expensive than Cap’n Proto. Python FlatBuffers write is the Python builder, not the format. `rkyv` is faster than `prost` here, but the clock still builds a full value.
- **What this does not answer:** Time to touch two fields only; safety of an unchecked buffer; official libprotobuf in C++; Java (no FlatBuffers client in the suite).

---

## After Experiment 8

- **Date:** 2026-08-17
- **Folder:** [08-human-files](08-human-files/)
- **Finding:** YAML is many times slower than JSON. XML is larger. They stay files people edit. Convert to JSON or Protocol Buffers when the process starts.
- **What this does not answer:** Whether operators prefer YAML in the editor; Python/Java/JS YAML (not registered next to JSON in those harnesses).

---

## After later experiments

*Each new experiment adds a block above this line. We do not rewrite old findings. We only change the list and the next question.*
