# Preview samples

These JSON files are reading copies of the shapes the experiments and the dashboard share. They are not rebuilt by a shared script. Do not edit them by hand.

| File | What it is |
|------|------------|
| `message.n1.json` | One flat record (eight fields). |
| `document.n1.json` | One order-like record (eight line items). |
| `event.n1.json` | One event (id, type, time, producer, four attributes). |
| `strings.n1.json` | One list of 32 short words. |
| `telemetry.points-8.json` | One sensor record with 8 numbers. |
| `telemetry.points-32.json` | Same shape, 32 numbers (the suite default). |
| `telemetry.points-128.json` | Same shape, 128 numbers. |
| `telemetry.points-512.json` | Same shape, 512 numbers. |

When a run writes one hundred records in one call, the runner builds records 0 through 99 with the same builder and seed. These files store one record.
