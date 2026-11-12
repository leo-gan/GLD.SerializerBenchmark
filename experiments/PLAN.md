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

The notebooks below were not re-run for Dagr or for the graph data set. Those rows are on the main Dashboard only. Dagr’s four layouts cover the five suite types in C++, Go, JavaScript, Mojo, Python, Rust, and Swift. `dagr-frozen-packed` is the fast small row on a flat `message`; it does not support `graph`. The `graph` data set is one book with shared region nodes and one person ring. `all@` does not include it. Only `dagr-regular`, `dagr-frozen`, and Python `pickle` / `cloudpickle` are timed on it.

---


## The samples (this is the data we measure)

Each experiment is one **question**. All settings live in that folder’s **`experiment.yaml`**. The saved record (`sample.json`) is **shared**. Each language run lives in a subfolder.

Preview copies of the shapes live in [`samples/`](samples/).

### One sensor record (`telemetry`)

Saved: [`samples/telemetry.points-8.json`](samples/telemetry.points-8.json) (and 32, 128, 512).
Used by: Experiment 1. Experiment 2 uses the 128-number list.

A source name, a time, two tags, and a list of numbers. Experiment 1 grows the list: 8, 32, 128, then 512.

### A list of words (`strings`)

Saved: [`samples/strings.n1.json`](samples/strings.n1.json).
Used by: Experiment 2.

Thirty-two short words. A few repeat, so a compressor has something to work with.

### One flat record (`message`)

Saved: [`samples/message.n1.json`](samples/message.n1.json).
Used by: Experiment 2.

Eight fields, no nesting.

### One order (`document`)

Saved: [`samples/document.n1.json`](samples/document.n1.json).
Used by: Experiments 3 and 4.

One record: an id, a status, a region, a version, and eight line items.

### One event (`event`)

Saved: [`samples/event.n1.json`](samples/event.n1.json).

A fact on a log: who produced it, when, what kind, and four extra attributes. The dashboard times this shape. None of the four experiments uses it as its question.

---

## The list of experiments

| # | Status | Question |
|---|--------|----------|
| 1 | **done** | When is JSON too big for a sensor? |
| 2 | **done** | Does squeezing the bytes make JSON small enough? |
| 3 | **done** | Does writing to a file change the ranking? |
| 4 | **done** | What does a Fortran call add? |

---

## Experiment 1 — When is JSON too big for a sensor?

**Status:** done for Rust (2026-08-16) and C (re-run 2026-08-17 after the runner honoured `points`).  
**Folder:** [01-sensor-list-size](01-sensor-list-size/). Combined page: [results.md](01-sensor-list-size/results.md). Combined JSON: [results.json](01-sensor-list-size/results.json).  
**Sample:** Sample C, 8, 32, 128, then 512 numbers, saved as [01-sensor-list-size/sample.json](01-sensor-list-size/sample.json).

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

- JSON is easy for a person to read. CBOR is built so a small radio can send fewer bytes.
- MessagePack and CBOR stay flexible. Protocol Buffers stay small as the list grows **if** the field list is stable.
- On a microcontroller, the size of the **library in flash** can matter more than 40 extra bytes on the wire. This benchmark measures the message, not the flash image.

### What this experiment cannot tell us

- How many bytes the library occupies in flash
- Battery use
- Whether the radio already compresses the packet
- C on this machine *(fixed 2026-08-17: the runner now reads `type_config.points`)*

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

**What this changes later:** Experiment 2 asks whether gzip or zstd changes the size story.

### What we found after the C fix (2026-08-17)

C sizes now grow with the list and match the Rust curve to within a few bytes. JSON (`yyjson`) is 226 B at 8 numbers (over 128), 661 B at 32 (over 512), 2418 B at 128, 9371 B at 512. `protobuf-wire` / `nanopb` are 105 / 317 / 1187 / 4640. MessagePack and CBOR sit between JSON and protobuf. The Rust reading still holds on C: leave JSON on the device at 32 numbers on a 512-byte packet.

---


## Experiment 2 — Does squeezing the bytes make JSON small enough?

**Status:** done for all nine languages (2026-08-17). Wrapper [#100](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/100) added `SizeGzip` / `SizeZstd`; this re-run filled the tables.  
**Folder:** [02-compression-size](02-compression-size/). Combined page: [results.md](02-compression-size/results.md). Combined JSON: [results.json](02-compression-size/results.json).  
**Sample:** Samples E, C (128 numbers), and B, saved as [02-compression-size/sample.json](02-compression-size/sample.json).

### The question

> After **gzip** or **zstd**, does JSON stay larger than a dense binary format — or does squeezing the bytes erase the reason to leave JSON?

### Why this is its own experiment

gzip and zstd find **repeated patterns** in any bytes. Protocol Buffers and MessagePack already drop field *names*. gzip finds a different kind of repetition (repeated words, repeated digits).

Teams often turn gzip on for everything. Large pages get smaller. Tiny control messages get **slower**, because the processor work exceeds the bytes you save.

### Real situation

A bandwidth ticket. Public HTTP may already compress. Chatty internal calls on a fast local network may not want a compressor on every message.

### What we already know

The runner can record **size after gzip** and **size after zstd** once per sample. On one shop order, named JSON went from 448 bytes to 229 bytes after gzip.

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

### What we found (2026-08-17)

First run was Python only. After the runner fix ([#100](https://github.com/leo-gan/GLD.SerializerBenchmark/pull/100)) we ran the same three samples in all nine languages.

| Sample | JSON raw | JSON gzip | protobuf raw | protobuf gzip |
|--------|----------|-----------|--------------|---------------|
| E words | 410 | 270 | 367 | 266 |
| C 128 numbers | 2407 | 1317 | 1061 | 1080 |
| B tiny | 168 | 138 | 50 | 71 |

Python numbers above. The other eight languages tell the same story: on words, gzip pulls JSON next to protobuf (about 270–291 vs 256–278); on numbers the format still matters (JSON gzip ~1220–1335 vs protobuf ~1068–1141); on the tiny record gzip **enlarges** protobuf and barely shrinks JSON. C# `Google.Protobuf` is a larger envelope on words (492 → 386). Do not compress chatty control calls. Combined page: [02-compression-size/results.md](02-compression-size/results.md).

---


## Experiment 3 — Does writing to a file change the ranking?

**Status:** done for Go, Java, and C++ (2026-08-17).  
**Folder:** [03-memory-vs-stream](03-memory-vs-stream/). Combined page: [results.md](03-memory-vs-stream/results.md). Combined JSON: [results.json](03-memory-vs-stream/results.json).  
**Sample:** Sample A, saved as [03-memory-vs-stream/sample.json](03-memory-vs-stream/sample.json).

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

### What we found (2026-08-17)

Only treat **real** stream rows as file/socket evidence.

- **Go:** among *real* streams, `goccy/go-json` stays first. `protobuf` is fastest on the stream column but that path is **copied**.
- **Java:** `jsoniter` is fastest in memory; its stream path is **copied**. Among real streams, `jackson` is first.
- **C++:** `protobuf-wire` is fastest in memory; its stream path is **copied**. Among real streams, `msgpack` is first.

A copied stream that matches in-memory is not a scandal. Claiming it as writing-as-you-go is.

---


## Experiment 4 — What does a Fortran call add?

**Status:** done for C and Fortran.
**Folder:** [04-fortran-ffi-tax](04-fortran-ffi-tax/). Combined page: [results.md](04-fortran-ffi-tax/results.md). Combined JSON: [results.json](04-fortran-ffi-tax/results.json).
**Sample:** one shop order, saved as [04-fortran-ffi-tax/sample.json](04-fortran-ffi-tax/sample.json).

### The question

> For one shop order, how much time does a Fortran call add over the C runner calling the same C library?

### Why this is its own experiment

The Fortran leaderboard times pure Fortran libraries. This experiment is the other question: how much the language crossing costs when the library is C.

### Real situation

A Fortran program already has the order in a Fortran type. Inside the timer it copies that order into the C structure and calls the same C adapter the C runner times.

### How we decide

The Fortran row includes that copy. Moving the copy outside the timer would hide the cost a Fortran caller pays. The gap between the two rows is the result. Do not pair a later C dashboard row with an older Fortran file. The two sides are one sitting.

### What this experiment cannot tell us

- A Fortran library that is not this C adapter
- Whether a different copy, outside the timer, would look faster

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
  01-sensor-list-size/
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

1. Write `experiment.yaml` (copy an existing experiment’s file and change it).
2. Save `sample.json` from that file.
3. Add language folders and a `run.sh`.
4. Write `summarize.py` so a dashboard can load `results.json`.
5. Measure, then add an **After Experiment *n*** block below. Do not commit `<lang>/logs/`.

Do not compare write times between language folders. Size is the only number that is roughly fair across languages, and only when both sides write the same field description.

