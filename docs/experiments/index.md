---
title: Experiments
---

# Experiments

[Dashboard → Experiments](../dashboard/#experiments){ .md-button .md-button--primary }

Each experiment answers **one everyday question**, such as “which JSON library is fastest?” or “is YAML too slow for a live request?”

Each experiment opens on a language tab. The **All** tab (last on the right) puts every language on one microsecond axis so you can compare runtimes. Color is still vs that language’s fastest. Size (how many bytes) is also fair across languages.

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

- The **bar** is the middle time (median), in **microseconds**. Smaller is faster.
- The **whisker** is **approximate spread**, reconstructed from the published confidence interval of the **mean**. It is the same reconstruction the table’s Spread column uses. It is not yet the sample standard deviation of the trials.
- Hover a bar for the same `15.9 (1.2×)` style numbers as the table.
- **Vs fastest** is still Fastest / About the same / A bit slower / Clearly slower — also shown as color + a glyph on the axis. A 2% gap is not “clearly slower.”
- The **All** tab uses the same **microsecond** axis as a language tab, so you can compare languages. Color is still vs that language’s fastest.
- A single-language tab is one contest inside that runtime.
- Some experiments add a size, compression, or rank chart when that is the question.
- Experiment 1 shows only libraries that write **named JSON** (`{"id": 1, "status": "ok"}`).

Use **Download CSV** or **Show numbers as a table** when you want the grid.

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

**Example:** When a shop’s website sends one order to a partner, it almost always uses JSON, because browsers and other companies already know how to read that text.

**Trade-off:** A faster JSON library can reduce the time spent writing and reading the text. A library that also checks that each field has the expected type will take longer. That extra time is spent on safety, not on speed.

**What counts:** only libraries that write named JSON (`{"id": …}`). A JSON list is a different payload, so it is not in this contest.

**Sample:** one shop order (an id, a status, eight line items, about 450 bytes). Not a file of many orders.

[Dashboard](../dashboard/#experiments/01-json-library-bakeoff) · [Folder](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/experiments/01-json-library-bakeoff)

### 2. Should two services inside the company stop using JSON?

Inside a company you may pick a denser format. That has a real cost (new tools, harder debugging). We measure whether the gain is large.

**Example:** Imagine two programs that your company owns. They send a small record to each other on a private network. No web browser is involved.

**Trade-off:** JSON is ordinary text, so a person can open the bytes and read the field names. MessagePack and Protocol Buffers usually write fewer bytes. Protocol Buffers requires both sides to share a list of field names and numbers before they talk. MessagePack does not require that shared list.

**Sample:** one flat record (eight fields, no nesting).

[Dashboard](../dashboard/#experiments/02-flat-record-formats)

### 3. Is a one-language format worth the lock-in?

Formats like Python pickle are built for one language talking to itself. Next year another service may need the same bytes.

**Example:** Suppose you store a value in a cache today and only your Python program writes that value. A few months later a second program, written in another language, cannot read the stored bytes.

**Trade-off:** A format built for one language can store that language’s objects in full. Programs written in other languages cannot read those bytes. Some of these formats can also run stored code when they read, which is a security risk.

**Sample:** the same flat record as experiment 2.

[Dashboard](../dashboard/#experiments/03-one-language-store)

### 4. When is JSON too big for a sensor?

A radio packet has a size limit. JSON writes extra text around every number.

**Example:** A small device sends a list of sensor readings. We grow the list from 8 readings to 32, then 128, then 512. Many radios can send at most 128 bytes or 512 bytes in one packet, and we use those two sizes as limits.

**Trade-off:** If the JSON text still fits in the packet, it is reasonable to keep JSON so that people can read the bytes. If JSON no longer fits, and a more compact format still fits, then the compact format is the one that can be sent.

**Sample:** a sensor record with a growing list of numbers.

[Dashboard](../dashboard/#experiments/04-sensor-list-size)

### 5. What should we use for an event log?

Event logs keep facts for months. Size drives disk cost. Write time drives the producer’s CPU.

**Example:** A shop writes an “order placed” record many times each day and keeps those records for months. Customers and partners still receive JSON at the public edge of the system.

**Trade-off:** JSON is easy for people to read, but old and new software can silently disagree about the fields. Avro and Protocol Buffers usually write fewer bytes and were designed so that old and new software can work together. A faster format is not useful if old and new versions cannot both read the log.

**Sample:** one event (who, when, what kind, four extra attributes).

[Dashboard](../dashboard/#experiments/05-event-log-formats)

### 6. Are database formats better for a normal service call?

BSON, Smile, and Ion were built for databases, not for a simple “write it all, read it all” call.

**Example:** BSON is the format MongoDB stores on disk. Smile is a compact format that some Java services use with Elasticsearch. In both cases the database is meant to skip through a large document.

**Trade-off:** These formats spend extra bytes so that a reader can skip a field it does not need. This experiment always reads the whole record, so that extra cost can look like a loss even when it would help a real database.

**Sample:** the same small order as experiment 1.

[Dashboard](../dashboard/#experiments/06-document-db-formats)

### 7. Fast to write, or fast to read?

Some libraries make reading cheap (look at the bytes as they arrived). Writing can be more expensive. Adding write + read hides that split.

**Example:** Think of a game file that is written once and then read many times, or a replay that many players open. Sometimes the reader needs only a few fields, not the whole record.

**Trade-off:** These libraries help when you write the record once and read it many times. They help less when you change the record on every request. Judge write time and read time separately. Do not add the two times together and treat the sum as the whole story.

**Sample:** one order, and a long list of sensor numbers.

[Dashboard](../dashboard/#experiments/07-write-once-read-many)

### 8. Can we send YAML on the live path?

YAML, TOML, and XML exist so people can edit files. They were not built for a live request.

**Example:** A service often reads a configuration file when it starts. YAML is a text format that people edit by hand. Someone may then propose sending that same YAML on every live request.

**Trade-off:** If people edit the file, YAML on disk is reasonable. Convert it once when the service starts. On the live request path, use JSON or a more compact format that was built for machines.

**Sample:** one order, and a list of words.

[Dashboard](../dashboard/#experiments/08-human-files)

### 9. Does squeezing the bytes make JSON small enough?

Teams often turn compression on for everything. Tiny messages can get slower, because the processor work exceeds the bytes you save.

**Example:** Compare a public web page, which is a large piece of text, with a small internal status message of a few dozen bytes.

**Trade-off:** When the text repeats many words, compressing JSON can make it almost as small as a compact binary format. When the payload is mostly numbers, the original format still decides the size. Compressing a tiny control message often costs more processor time than it saves in bytes.

**Sample:** a list of words, a sensor list, and a tiny record.

[Dashboard](../dashboard/#experiments/09-compression-size)

### 10. Does one record rank the same as one hundred?

A web call is usually one body. A log shipper often writes many records at once. Some libraries have a large cost every time you call them.

**Example:** A typical web request sends one record, such as one user’s details. A telemetry program may send one hundred readings in a single write.

**Trade-off:** Report the time for the number of records your product actually writes. The time for one hundred records is not evidence for a call that writes one record.

**Sample:** a flat record and an event, at 1 and at 100.

[Dashboard](../dashboard/#experiments/10-one-vs-hundred)

### 11. Does writing to a file change the ranking?

A cache uses a block of bytes in memory. A file or socket writes as you go. Some “stream” numbers are a full result that is then copied.

**Example:** Saving a value in an in-memory cache is different from writing a file or sending bytes on a network connection.

**Trade-off:** Use a true stream measurement only when you are judging a file or a network write. If the product is a cache, the in-memory measurement is the one that matters.

**Sample:** one order, in memory and as if to a file.

[Dashboard](../dashboard/#experiments/11-memory-vs-stream)

### 12. Is it the format, or the library?

People say “we switched to binary” as if the name were the whole decision. Two libraries that both write JSON can still differ a lot.

**Example:** In Java, the Jackson library can write JSON and several other formats. We keep Jackson fixed and change only the format it writes, so the library itself is not the variable.

**Trade-off:** The result describes this one library. It does not describe every library that writes MessagePack. Changing format without naming the library is not a complete plan.

**Sample:** one order.

[Dashboard](../dashboard/#experiments/12-format-vs-library)

### 13. Does the ranking stay the same if we change the data?

One run on one computer is one evening’s measurement. A ranking that flips when we change the data was never a fact about the libraries.

**Example:** The JSON library that is fastest on one shop order may not be fastest on a list of words, or when we write one hundred records at once.

**Trade-off:** If one library is much faster on every sample we tried, that difference is stable enough to report. If two libraries keep exchanging first place, the contest is too close to name a single winner.

**Sample:** every record shape in this project, at 1 and at 100.

[Dashboard](../dashboard/#experiments/13-ranking-accident)

### 14. What is a starter kit of serializers for typical jobs?

A team often needs to start today, not after ranking every library. We time a short list that covers three usual jobs: public JSON, compact bytes inside the company, and a shared field file.

**Example:** You are starting a shop service. Partners will call you with JSON. Later you may add a private path to another service you own, and still later a second language may need the same record.

**Trade-off:** This is a place to begin, not a prize. Built-in JSON is familiar. The faster JSON library from Experiment 1 writes the same named text. MessagePack writes fewer bytes and does not need a shared field file. Protocol Buffers is usually smaller still, but both sides must share the field numbers. Pick the row that matches the job you have.

**Sample:** the same small order as experiment 1.

[Dashboard](../dashboard/#experiments/14-starter-kit) · [Folder](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/experiments/14-starter-kit)

---

## The records we use

The words look random because a small number generator built them. That is on purpose: every run with the same seed produces the same words.

**One order** (experiments 1, 6, 7, 8, 12, 14):

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
