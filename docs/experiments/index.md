---
title: Experiments
---

# Experiments

[Dashboard → Experiments](../dashboard/#experiments){ .md-button .md-button--primary }

A single experiment and language: `#experiments/{id}/{lang}` (example:
[Sensor list · Rust](../dashboard/#experiments/01-sensor-list-size/rust)).

Each experiment answers **one question** that Overview, Compare, and Compliance do not already hold. Overview and Compare have one standard, one data type, one record or one hundred, write time, read time, and raw size. Compliance is spec pass and fail.

An experiment remains for a growing sensor list, size after gzip and zstd, a real stream ranking, or the Fortran call over the same C library.

Each experiment opens on a language tab. The **All** tab puts every language on one microsecond axis. Color is still versus that language’s fastest. Size is fair across languages.

---

## 1. When is JSON too big for a sensor?

A radio packet has a size limit. JSON writes extra text around every number.

**Example:** A small device sends a list of sensor readings. We grow the list from 8 readings to 32, then 128, then 512. Many radios can send at most 128 bytes or 512 bytes in one packet, and we use those two sizes as limits.

**Trade-off:** If the JSON text still fits the packet, it is reasonable to keep JSON so that people can read the bytes. If JSON no longer fits, and a more compact format still fits, then the compact format is the one that can be sent. Kiln is one of those compact formats, on the languages that have it.

**Sample:** a sensor record. The list grows through 8, 32, 128, and 512 numbers.

[Dashboard](../dashboard/#experiments/01-sensor-list-size)

### 2. Does squeezing the bytes make JSON small enough?

Teams often turn compression on for everything. Tiny messages can get slower, because the processor work exceeds the bytes you save.

**Example:** Compare a public web page, which is a large piece of text, with a small internal status message of a few dozen bytes.

**Trade-off:** When the text repeats many words, compressing JSON can make it almost as small as a compact binary format. When the payload is mostly numbers, the original format still decides the size. Compressing a tiny control message often costs more processor time than it saves in bytes. Kiln sits with the other dense formats on the languages that have it.

**Sample:** a list of words, a sensor list of 128 numbers, and a tiny flat record.

[Dashboard](../dashboard/#experiments/02-compression-size)

### 3. Does writing to a file change the ranking?

A cache uses a block of bytes in memory. A file or socket writes as you go. Some “stream” numbers are a full result that is then copied.

**Example:** Saving a value in an in-memory cache is different from writing a file or sending bytes on a network connection.

**Trade-off:** Use a true stream measurement only when you are judging a file or a network write. If the product is a cache, the in-memory measurement is the one that matters.

**Sample:** one order, in memory and as if to a file.

[Dashboard](../dashboard/#experiments/03-memory-vs-stream)

### 4. What does a Fortran call add?

The Fortran leaderboard times pure Fortran libraries. This experiment times the same C library from the C runner and from Fortran, including the copy into the C structure.

**Example:** A Fortran program already has the order in a Fortran type. Inside the timer it copies that order into the C structure and calls the same C adapter the C runner times.

**Trade-off:** The Fortran row includes that copy. Moving the copy outside the timer would hide the cost a Fortran caller pays. The gap is the result.

**Sample:** one shop order.

[Dashboard](../dashboard/#experiments/04-fortran-ffi-tax)

---

## The records we use

The words look random because a small number generator built them. That is on purpose: every run with the same seed produces the same words.

**Sensor readings** (experiments 1 and 2): a source name, a time, two tags, and a list of numbers. Experiment 1 grows the list through 8, 32, 128, and 512 numbers. Experiment 2 uses 128 numbers.

**A list of words** (experiment 2): thirty-two short words. A few repeat, so a compressor has something to work with.

**One flat record** (experiment 2): eight fields, no nesting.

**One order** (experiments 3 and 4): an id, a status, a region, a version, and eight line items.

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

---

The lab notebook is [`experiments/PLAN.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/experiments/PLAN.md). New experiment folders appear on the Dashboard after `python3 dashboard/scripts/sync-experiments.py`.
