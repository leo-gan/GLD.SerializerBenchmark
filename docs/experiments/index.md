---
title: Experiments
---

# Experiments

Each experiment answers **one everyday question**, such as “which JSON library is fastest?” or “is YAML too slow for a live request?”

Open the numbers in the [Dashboard → Experiments](../dashboard/#experiments) tab. This page is the same story in words.

Compare libraries **inside one language**. A Python time and a Java time are not the same contest. Size (how many bytes) is the only number that is roughly fair across languages.

---

## Why experiments, if the Dashboard already has every number?

The main Dashboard is the **full set of measurements**. Every language, every library we registered, every record shape, both “in memory” and “as if to a file.” It is the warehouse. You can browse, sort, and compare.

That warehouse is easy to misuse.

If you open Python and sort by speed, the top row might be a library you **cannot use** for your job. It might write bytes that only Python can read. It might skip field names so partners cannot parse the text. It might be built for a game file you write once, not for a web request you write on every click. The Dashboard will still put that row at the top, because it is fast.

An experiment is the opposite of “show me everything.” We start with a **decision**:

> We must keep JSON on the public website. Which JSON library is fast enough?

Then we keep **only** the libraries that could be the answer. We time **one** record (the same one for everyone in that test). We write down what we would give up if we picked the faster row.

Think of a grocery store and a recipe. The store has every product. That is the main Dashboard. The recipe lists only what you need for tonight’s dinner, and why. That is an experiment. You need both. The store does not tell you what to cook. The recipe does not replace the store.

### What goes wrong if we only use the big table

**1. Different jobs sit in the same list.**  
JSON (text people can read), MessagePack (compact bytes, no shared field file), Protocol Buffers (shared field numbers), and Python pickle (Python only) can all appear in one language table. “What is fastest?” is not one question. “What is fastest **for a public API that must stay JSON**?” is one question. Experiment 1 is that question. Experiment 2 is a different question: “may we leave JSON on a private path?”

**2. A small gap looks like a winner.**  
On a tiny record, 1.7 µs versus 1.8 µs is not a reason to rewrite a service. The experiment page says when the gap is “about the same” or “a bit slower,” so we do not crown a winner we cannot defend.

**3. The Dashboard does not know your constraint.**  
You may be stuck with JSON because browsers and partners already speak it. You may be stuck with Protocol Buffers because two languages share a field file. The big table cannot hide the rows that break that rule. An experiment can.

**4. One record is not one hundred records.**  
A web call is usually one body. A log shipper often writes many records at once. The library that wins at 1 can lose at 100 (Experiment 10). The main Dashboard shows both, side by side. Without the experiment, it is easy to quote the wrong column.

**5. Size after gzip is not the same as raw size.**  
Teams say “just turn compression on.” Experiment 9 asks whether that erases the reason to leave JSON. The main Dashboard can show extra size columns. It does not ask the question or name the three records we used (words, numbers, a tiny ping).

**6. Numbers without a story invite the wrong change.**  
A common mistake: someone sees “binary is faster,” changes the public website, and then spends months helping partners who can no longer use ordinary tools. Experiments exist so we **ask a narrow question first**, measure only that, and then decide.

### What an experiment adds that the big table does not

| The main Dashboard | An experiment |
|--------------------|---------------|
| Every library we measured | Only libraries that could answer **this** question |
| Every record shape, mixed | One record (or a planned set), named and shown |
| Speed, size, charts | The same numbers, plus **why**, an **example**, and the **trade-off** |
| You pick the filter | We already picked the fair comparison |
| Easy to browse | Built to support **one decision** |

The experiment still uses the same clock and the same record builder. We do not invent a second benchmark. We **cut the big table down to a fair contest** and write the story next to it.

If you only want to look around, use the main Dashboard. If you have to choose a library for a real service, start with the experiment that matches your constraint.

---

## How to read the graphs

Only **Experiment 1** is graphed so far. The other experiments still use a table. The numbers mean the same thing.

Open them in the [Dashboard → Experiments](../dashboard/#experiments) tab.

- The **bar** is the middle time (median), in **microseconds**. Smaller is faster.
- The **whisker** is **approximate spread**, reconstructed from the published confidence interval of the **mean**. It is the same reconstruction the table’s Spread column uses. It is not yet the sample standard deviation of the trials.
- Hover a bar for the same `15.9 (1.2×)` style numbers as the table.
- **Vs fastest** is still Fastest / About the same / A bit slower / Clearly slower — also shown as color + a glyph on the axis.
- Compare libraries **inside one language**.
- Experiment 1 shows only libraries that write **named JSON** (`{"id": 1, "status": "ok"}`). A JSON list is a different public-API payload, so it is not on that chart.

Use **Download CSV** or **Show numbers as a table** when you want the grid. Experiments 2–13 stay on the table until they are opted in.

### The downloadable table

Times are the **middle** value (the median), in **microseconds**. Smaller is better for time and for size.

Each time and size cell looks like `15.9 (1.2×)`:

- `15.9` is the number.
- `(1.2×)` means “1.2 times the fastest row in this table.”
- **Green** = better than the fastest (or equal). **Red** = worse. The fastest row is `1.0×`.

**Trials** is how many timed runs we kept (for example 92 of 100). We drop the first run (the computer is still warming up) and we may set aside rare stalls.

**Spread (std)** is how much those times bounced around. A smaller spread means a more stable number.

### What “Vs fastest” means

This is **not** simply Winner / Loser. Two libraries can be too close to call on this sample.

| Label | Meaning |
|-------|---------|
| **Fastest** | The one we measure the others against, on this sample |
| **About the same** | We cannot tell it apart from the fastest here |
| **A bit slower** | Slower, but a different record could change the order |
| **Clearly slower** | A clear gap on this sample |
| **Good trade-off** | Nobody is both faster **and** smaller. This library is on that front. |

A different record, or a hundred records instead of one, can change the order. Experiment 13 checks that.

---

## The experiments

### 1. Which JSON library is fastest?

We have to send JSON (the usual web text). Changing that format is expensive. First we ask whether a faster JSON library is enough.

**Example:** A shop’s public API sends one order as JSON. Partners and browsers already expect that text.

**Trade-off:** A faster library can help a lot. A library that checks types is slower on purpose — that extra time buys safety.

**What counts:** only libraries that write named JSON (`{"id": …}`). A JSON list is a different payload, so it is not in this contest.

**Sample:** one shop order (an id, a status, eight line items, about 450 bytes). Not a file of many orders.

[Dashboard](../dashboard/#experiments/01-json-library-bakeoff) · [Folder](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/experiments/01-json-library-bakeoff)

### 2. Should two services inside the company stop using JSON?

Inside a company you may pick a denser format. That has a real cost (new tools, harder debugging). We measure whether the gain is large.

**Example:** Two services you own swap a small request on a private network. No browser is on this path.

**Trade-off:** JSON is easy to read at 3 a.m. MessagePack and Protocol Buffers write smaller bytes. Protocol Buffers needs a shared field list.

**Sample:** one flat record (eight fields, no nesting).

[Dashboard](../dashboard/#experiments/02-flat-record-formats)

### 3. Is a one-language format worth the lock-in?

Formats like Python pickle are built for one language talking to itself. Next year another service may need the same bytes.

**Example:** A cache or a job queue that “only we write today.”

**Trade-off:** Other languages cannot read it. Some of these readers can run code — that is a safety problem.

**Sample:** the same flat record as experiment 2.

[Dashboard](../dashboard/#experiments/03-one-language-store)

### 4. When is JSON too big for a sensor?

A radio packet has a size limit. JSON writes extra text around every number.

**Example:** A device sends 8, then 32, then 128, then 512 readings. We mark two example limits: 128 bytes and 512 bytes.

**Trade-off:** Stay on JSON if it still fits, so people can read the packets. Leave JSON when the packet overflows and a denser format still fits.

**Sample:** a sensor record with a growing list of numbers.

[Dashboard](../dashboard/#experiments/04-sensor-list-size)

### 5. What should we use for an event log?

Event logs keep facts for months. Size drives disk cost. Write time drives the producer’s CPU.

**Example:** “Order placed” is written many times a day and stored for months. Outside parties still get JSON at the edge.

**Trade-off:** JSON is easy to read and can drift. Avro and Protocol Buffers are smaller. Speed cannot override a failed compatibility story.

**Sample:** one event (who, when, what kind, four extra attributes).

[Dashboard](../dashboard/#experiments/05-event-log-formats)

### 6. Are database formats better for a normal service call?

BSON, Smile, and Ion were built for databases, not for a simple “write it all, read it all” call.

**Example:** A program talking to MongoDB, or Java services talking to Elasticsearch.

**Trade-off:** These formats spend bytes so a reader can skip a field. This test always reads the whole record, so that extra may look like a loss.

**Sample:** the same small order as experiment 1.

[Dashboard](../dashboard/#experiments/06-document-db-formats)

### 7. Fast to write, or fast to read?

Some libraries make reading cheap (look at the bytes as they arrived). Writing can be more expensive. Adding write + read hides that split.

**Example:** A game asset or a replay file that one program builds and another reads many times.

**Trade-off:** Good when you write once and read often. Poor when you change the record on every request. Look at write and read separately.

**Sample:** one order, and a long list of sensor numbers.

[Dashboard](../dashboard/#experiments/07-write-once-read-many)

### 8. Can we send YAML on the live path?

YAML, TOML, and XML exist so people can edit files. They were not built for a live request.

**Example:** A service reads a config file at start. Someone proposes sending that same YAML on every request.

**Trade-off:** Keep YAML on disk if people edit it. Convert once at start. Use JSON (or a denser format) on the live path.

**Sample:** one order, and a list of words.

[Dashboard](../dashboard/#experiments/08-human-files)

### 9. Does squeezing the bytes make JSON small enough?

Teams often turn compression on for everything. Tiny messages can get slower, because the processor work exceeds the bytes you save.

**Example:** A public web page (large text) versus a chatty internal ping (a few dozen bytes).

**Trade-off:** On repeated words, compression can pull JSON next to a dense format. On numbers, the format still matters. Do not compress tiny control calls.

**Sample:** a list of words, a sensor list, and a tiny record.

[Dashboard](../dashboard/#experiments/09-compression-size)

### 10. Does one record rank the same as one hundred?

A web call is usually one body. A log shipper often writes many records at once. Some libraries have a large cost every time you call them.

**Example:** One “get user” request versus a telemetry exporter that sends 100 readings in one write.

**Trade-off:** Quote the number of records that matches the product. A chart of 100 records is not evidence for a one-record call.

**Sample:** a flat record and an event, at 1 and at 100.

[Dashboard](../dashboard/#experiments/10-one-vs-hundred)

### 11. Does writing to a file change the ranking?

A cache uses a block of bytes in memory. A file or socket writes as you go. Some “stream” numbers are a full result that is then copied.

**Example:** Saving a cache key versus writing a file or a network socket.

**Trade-off:** Only treat a real stream path as evidence for a file. If the product is a cache, the in-memory number is the one that matters.

**Sample:** one order, in memory and as if to a file.

[Dashboard](../dashboard/#experiments/11-memory-vs-stream)

### 12. Is it the format, or the library?

People say “we switched to binary” as if the name were the whole decision. Two libraries that both write JSON can still differ a lot.

**Example:** Jackson in Java can write JSON, MessagePack, Smile, and more. We hold Jackson still and only change what it writes.

**Trade-off:** This tells you about that one library, not about every MessagePack library in the world.

**Sample:** one order.

[Dashboard](../dashboard/#experiments/12-format-vs-library)

### 13. Does the ranking stay the same if we change the data?

One run on one computer is one evening’s measurement. A ranking that flips when we change the data was never a fact about the libraries.

**Example:** The fastest JSON library on one order may not stay fastest on a list of words, or when we write 100 records at once.

**Trade-off:** A large gap that holds on every sample is a stable fact. A close contest that swaps places is too close to name a winner.

**Sample:** every record shape in this project, at 1 and at 100.

[Dashboard](../dashboard/#experiments/13-ranking-accident)

---

## The records we use

The words look random because a small number generator built them. That is on purpose: every run with the same seed produces the same words.

**One order** (experiments 1, 6, 7, 8, 12):

```json
{
  "id": "btimcpxm",
  "status": 4,
  "meta": { "region": "al", "version": 3 },
  "items": [
    { "sku": "ytgl", "qty": 10, "price_minor": 55613 }
  ]
}
```

(The real sample has eight line items.)

**One flat record** (experiments 2, 3, 10):

```json
{
  "f_bool": true,
  "f_int32": 442269,
  "f_int64": 446816,
  "f_float64": 649.197,
  "f_string": "xljybqxfemz",
  "f_bool_2": false,
  "f_int32_2": 598855,
  "f_string_2": "eobwzfgdqglt"
}
```

**Sensor readings** (experiments 4, 7, 9): a source name, a time, two tags, and a list of numbers. Experiment 4 grows the list: 8, 32, 128, then 512 numbers.

**One event** (experiments 5, 10): who produced it, when, what kind, and four extra attributes.

**A list of words** (experiments 8, 9): thirty-two short words. A few repeat, so a compressor has something to work with.

---

The lab notebook with every finding lives in [`experiments/PLAN.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/experiments/PLAN.md). New experiment folders appear on the Dashboard after `python3 dashboard/scripts/sync-experiments.py`.
