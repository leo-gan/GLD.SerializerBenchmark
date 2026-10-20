//! gld-kiln adapter for the five suite structs and the tensor set.
//!
//! Timed encode and decode use the positional scalar writers and [`Reader`].
//! Numeric lists are one little-endian copy, the same shape as Mojo `encode`
//! on a `List[Float32]`. The dynamic [`kiln::Value`] tree is not on this path:
//! one `Value::F32` per matrix element made a 1024×1024 read allocate about a
//! million enums.
//!
//! N=1 is the struct alone. N>1 is one `list` of that struct.
//! `tensor_view` decode borrows the f32 payload and does not copy the matrix.

use crate::data::{
    Document, DocumentItem, DocumentMeta, Event, EventAttr, F32Payload, Fixture, InferenceRequest,
    Message, Prompt, Shard, Strings, Telemetry, TensorMatrix,
};
use crate::serializers::{BenchSerializer, NativeKind, StreamMode};
use anyhow::{bail, Context, Result};
use kiln::{
    write_bool, write_count, write_f32, write_f64, write_i32, write_i64, write_str, Reader,
    DEFAULT_CAP,
};
use std::io::Read;

const SUITE: &[&str] = &["message", "document", "telemetry", "strings", "event"];
const TENSOR: &[&str] = &["tensor", "tensor_view", "prompt", "shard", "request"];

fn err(error: kiln::Error) -> anyhow::Error {
    anyhow::anyhow!("gld-kiln: {error}")
}

fn extend_le<T>(out: &mut Vec<u8>, values: &[T]) {
    let nbytes = std::mem::size_of_val(values);
    if nbytes == 0 {
        return;
    }
    if cfg!(target_endian = "little") {
        // SAFETY: `values` is one contiguous slice. On a little-endian host
        // those bytes are already Kiln's wire order. The slice is only read.
        let bytes = unsafe { std::slice::from_raw_parts(values.as_ptr().cast::<u8>(), nbytes) };
        out.extend_from_slice(bytes);
        return;
    }
    panic!("gld-kiln numeric copy requires a little-endian host");
}

fn read_le<T: Copy>(bytes: &[u8], n: usize) -> Result<Vec<T>> {
    let width = std::mem::size_of::<T>();
    let nbytes = n.checked_mul(width).context("gld-kiln list length")?;
    if bytes.len() != nbytes {
        bail!("gld-kiln list length");
    }
    let mut out = Vec::<T>::with_capacity(n);
    if n == 0 {
        return Ok(out);
    }
    if cfg!(target_endian = "little") {
        // SAFETY: `bytes` holds `n` little-endian `T` values and `out` has
        // room for all of them. `T` is a plain number. `set_len` runs only
        // after every byte has been copied.
        unsafe {
            std::ptr::copy_nonoverlapping(bytes.as_ptr(), out.as_mut_ptr().cast::<u8>(), nbytes);
            out.set_len(n);
        }
        return Ok(out);
    }
    bail!("gld-kiln numeric copy requires a little-endian host");
}

fn write_f32_payload(out: &mut Vec<u8>, values: &F32Payload) -> Result<()> {
    let n = values.len();
    write_count(out, n, DEFAULT_CAP).map_err(err)?;
    out.reserve(n.saturating_mul(4));
    match values {
        F32Payload::Owned(items) => extend_le(out, items),
        F32Payload::Borrowed(_) => {
            for i in 0..n {
                out.extend_from_slice(&values.bit(i).to_le_bytes());
            }
        }
    }
    Ok(())
}

fn write_f32s(out: &mut Vec<u8>, values: &[f32]) -> Result<()> {
    write_count(out, values.len(), DEFAULT_CAP).map_err(err)?;
    out.reserve(values.len().saturating_mul(4));
    extend_le(out, values);
    Ok(())
}

fn write_f64s(out: &mut Vec<u8>, values: &[f64]) -> Result<()> {
    write_count(out, values.len(), DEFAULT_CAP).map_err(err)?;
    out.reserve(values.len().saturating_mul(8));
    extend_le(out, values);
    Ok(())
}

fn write_i64s(out: &mut Vec<u8>, values: &[i64]) -> Result<()> {
    write_count(out, values.len(), DEFAULT_CAP).map_err(err)?;
    out.reserve(values.len().saturating_mul(8));
    extend_le(out, values);
    Ok(())
}

fn write_strs(out: &mut Vec<u8>, values: &[String]) -> Result<()> {
    write_count(out, values.len(), DEFAULT_CAP).map_err(err)?;
    for value in values {
        write_str(out, value, DEFAULT_CAP).map_err(err)?;
    }
    Ok(())
}

// Library scalar writers. A hand-rolled copy of the same fields was slower
// on message n=1 in the harness (about 170 ns versus about 30 ns).
fn write_message(out: &mut Vec<u8>, value: &Message) -> Result<()> {
    write_bool(out, value.f_bool);
    write_i32(out, value.f_int32);
    write_i64(out, value.f_int64);
    write_f64(out, value.f_float64);
    write_str(out, &value.f_string, DEFAULT_CAP).map_err(err)?;
    write_bool(out, value.f_bool_2);
    write_i32(out, value.f_int32_2);
    write_str(out, &value.f_string_2, DEFAULT_CAP).map_err(err)?;
    Ok(())
}

fn write_document(out: &mut Vec<u8>, value: &Document) -> Result<()> {
    write_str(out, &value.id, DEFAULT_CAP).map_err(err)?;
    write_i32(out, value.status);
    write_str(out, &value.meta.region, DEFAULT_CAP).map_err(err)?;
    write_i32(out, value.meta.version);
    write_count(out, value.items.len(), DEFAULT_CAP).map_err(err)?;
    for item in &value.items {
        write_str(out, &item.sku, DEFAULT_CAP).map_err(err)?;
        write_i32(out, item.qty);
        write_i64(out, item.price_minor);
    }
    Ok(())
}

fn write_telemetry(out: &mut Vec<u8>, value: &Telemetry) -> Result<()> {
    write_str(out, &value.source, DEFAULT_CAP).map_err(err)?;
    write_i64(out, value.ts);
    write_strs(out, &value.tags)?;
    write_f64s(out, &value.values)?;
    Ok(())
}

fn write_strings(out: &mut Vec<u8>, value: &Strings) -> Result<()> {
    write_strs(out, &value.items)
}

fn write_event(out: &mut Vec<u8>, value: &Event) -> Result<()> {
    write_str(out, &value.event_id, DEFAULT_CAP).map_err(err)?;
    write_str(out, &value.event_type, DEFAULT_CAP).map_err(err)?;
    write_i64(out, value.occurred_at);
    write_str(out, &value.producer, DEFAULT_CAP).map_err(err)?;
    write_count(out, value.attrs.len(), DEFAULT_CAP).map_err(err)?;
    for attr in &value.attrs {
        write_str(out, &attr.key, DEFAULT_CAP).map_err(err)?;
        write_str(out, &attr.value, DEFAULT_CAP).map_err(err)?;
    }
    Ok(())
}

fn write_prompt(out: &mut Vec<u8>, value: &Prompt) -> Result<()> {
    write_i32(out, value.batch);
    write_i32(out, value.seq);
    write_i64s(out, &value.input_ids)?;
    write_i64s(out, &value.attention_mask)?;
    write_i64s(out, &value.position_ids)?;
    Ok(())
}

fn write_shard(out: &mut Vec<u8>, value: &Shard) -> Result<()> {
    write_i32(out, value.vocab);
    write_i32(out, value.hidden);
    write_i32(out, value.ffn);
    write_f32s(out, &value.tok_emb)?;
    write_f32s(out, &value.attn)?;
    write_f32s(out, &value.ffn_weight)?;
    write_f32s(out, &value.norm)?;
    Ok(())
}

fn write_request(out: &mut Vec<u8>, value: &InferenceRequest) -> Result<()> {
    write_i64(out, value.request_id);
    write_str(out, &value.model, DEFAULT_CAP).map_err(err)?;
    write_f32(out, value.temperature);
    write_prompt(out, &value.inputs)
}

fn write_tensor(out: &mut Vec<u8>, value: &TensorMatrix) -> Result<()> {
    write_i32(out, value.rows);
    write_i32(out, value.cols);
    write_f32_payload(out, &value.values)
}

fn write_one(out: &mut Vec<u8>, fx: &Fixture) -> Result<()> {
    match fx {
        Fixture::Message(value) => write_message(out, value),
        Fixture::Document(value) => write_document(out, value),
        Fixture::Telemetry(value) => write_telemetry(out, value),
        Fixture::Strings(value) => write_strings(out, value),
        Fixture::Event(value) => write_event(out, value),
        Fixture::Tensor(value) | Fixture::TensorView(value) => write_tensor(out, value),
        Fixture::Prompt(value) => write_prompt(out, value),
        Fixture::Shard(value) => write_shard(out, value),
        Fixture::Request(value) => write_request(out, value),
        other => bail!("gld-kiln: unsupported fixture {}", other.name()),
    }
}

fn read_string(reader: &mut Reader<'_>) -> Result<String> {
    let text = reader.string().map_err(err)?;
    let mut out = crate::data::take_string();
    out.clear();
    out.push_str(text);
    Ok(out)
}

fn read_string_list(reader: &mut Reader<'_>) -> Result<Vec<String>> {
    let n = reader.list_count(4).map_err(err)? as usize;
    let mut out = Vec::with_capacity(n);
    for _ in 0..n {
        out.push(read_string(reader)?);
    }
    Ok(out)
}

fn read_body<'a>(reader: &mut Reader<'a>, n: usize, width: usize) -> Result<&'a [u8]> {
    let nbytes = n.checked_mul(width).context("gld-kiln list length")?;
    reader.raw(nbytes).map_err(err)
}

fn read_f32s(reader: &mut Reader<'_>) -> Result<Vec<f32>> {
    let n = reader.list_count(4).map_err(err)? as usize;
    let bytes = read_body(reader, n, 4)?;
    let mut out = crate::data::take_f32_buf(n);
    if n == 0 {
        return Ok(out);
    }
    if cfg!(target_endian = "little") {
        // SAFETY: `bytes` is `n` little-endian f32s and `out` has that capacity.
        // `set_len` runs only after the copy has initialized every element.
        unsafe {
            std::ptr::copy_nonoverlapping(
                bytes.as_ptr(),
                out.as_mut_ptr().cast::<u8>(),
                bytes.len(),
            );
            out.set_len(n);
        }
        return Ok(out);
    }
    bail!("gld-kiln numeric copy requires a little-endian host");
}

fn read_f64s(reader: &mut Reader<'_>) -> Result<Vec<f64>> {
    let n = reader.list_count(8).map_err(err)? as usize;
    read_le(read_body(reader, n, 8)?, n)
}

fn read_i64s(reader: &mut Reader<'_>) -> Result<Vec<i64>> {
    let n = reader.list_count(8).map_err(err)? as usize;
    read_le(read_body(reader, n, 8)?, n)
}

fn take_bytes<'a>(data: &'a [u8], i: &mut usize, n: usize) -> Result<&'a [u8]> {
    let end = i.checked_add(n).context("gld-kiln list length")?;
    if end > data.len() {
        bail!("gld-kiln: EOF");
    }
    let out = &data[*i..end];
    *i = end;
    Ok(out)
}

fn take_u32(data: &[u8], i: &mut usize) -> Result<u32> {
    let bytes = take_bytes(data, i, 4)?;
    Ok(u32::from_le_bytes(bytes.try_into().unwrap()))
}

fn copy_utf8(bytes: &[u8]) -> Result<String> {
    if bytes.len() as u64 > DEFAULT_CAP {
        bail!("gld-kiln: LIMIT");
    }
    // Bytes below 0x80 are ASCII, which is valid UTF-8. Non-ASCII still
    // goes through the full checker. Suite strings are short ASCII words.
    if bytes.iter().any(|byte| *byte >= 0x80) {
        std::str::from_utf8(bytes).map_err(|_| anyhow::anyhow!("gld-kiln: UTF8"))?;
    }
    let mut out = crate::data::take_string();
    out.clear();
    if out.capacity() < bytes.len() {
        out.reserve(bytes.len());
    }
    // SAFETY: `reserve` left room for `bytes.len()` initialized bytes.
    // `from_utf8` already accepted them.
    unsafe {
        let dest = out.as_mut_vec();
        std::ptr::copy_nonoverlapping(bytes.as_ptr(), dest.as_mut_ptr(), bytes.len());
        dest.set_len(bytes.len());
    }
    Ok(out)
}

fn read_message_at(data: &[u8], i: &mut usize) -> Result<Message> {
    let tag = take_bytes(data, i, 1)?[0];
    let f_bool = match tag {
        0 => false,
        1 => true,
        _ => bail!("gld-kiln: TYPE"),
    };
    let f_int32 = take_u32(data, i)? as i32;
    let f_int64 = i64::from_le_bytes(take_bytes(data, i, 8)?.try_into().unwrap());
    let f_float64 = f64::from_le_bytes(take_bytes(data, i, 8)?.try_into().unwrap());
    let n1 = take_u32(data, i)? as usize;
    let s1 = take_bytes(data, i, n1)?;
    let tag2 = take_bytes(data, i, 1)?[0];
    let f_bool_2 = match tag2 {
        0 => false,
        1 => true,
        _ => bail!("gld-kiln: TYPE"),
    };
    let f_int32_2 = take_u32(data, i)? as i32;
    let n2 = take_u32(data, i)? as usize;
    let s2 = take_bytes(data, i, n2)?;
    Ok(Message {
        f_bool,
        f_int32,
        f_int64,
        f_float64,
        f_string: copy_utf8(s1)?,
        f_bool_2,
        f_int32_2,
        f_string_2: copy_utf8(s2)?,
    })
}

fn read_message_one(data: &[u8]) -> Result<Fixture> {
    let mut i = 0usize;
    let message = read_message_at(data, &mut i)?;
    if i != data.len() {
        bail!("gld-kiln: TRAILING");
    }
    Ok(Fixture::Message(message))
}

fn read_message_list(data: &[u8]) -> Result<Fixture> {
    let mut i = 0usize;
    let n = take_u32(data, &mut i)? as usize;
    if n as u64 > DEFAULT_CAP {
        bail!("gld-kiln: LIMIT");
    }
    if data.len() < 4 + n.saturating_mul(34) {
        bail!("gld-kiln: EOF");
    }
    let mut rows = Vec::with_capacity(n);
    for _ in 0..n {
        rows.push(Fixture::Message(read_message_at(data, &mut i)?));
    }
    if i != data.len() {
        bail!("gld-kiln: TRAILING");
    }
    Ok(Fixture::Rows(rows))
}

fn message_wire_len(value: &Message) -> usize {
    34 + value.f_string.len() + value.f_string_2.len()
}

fn write_message_list(fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
    let mut total = 4usize;
    for fx in fixtures {
        let Fixture::Message(value) = fx else {
            bail!("gld-kiln: mixed cell");
        };
        if value.f_string.len() > u32::MAX as usize || value.f_string_2.len() > u32::MAX as usize {
            bail!("gld-kiln: LIMIT");
        }
        total = total.saturating_add(message_wire_len(value));
    }
    let start = out.len();
    out.reserve(total);
    // SAFETY: `reserve` leaves `total` spare bytes. The stores below fill
    // that range before it is read.
    unsafe { out.set_len(start + total) };
    let dst = &mut out[start..];
    let mut at = 0usize;
    dst[at..at + 4].copy_from_slice(&(fixtures.len() as u32).to_le_bytes());
    at += 4;
    for fx in fixtures {
        let Fixture::Message(value) = fx else {
            bail!("gld-kiln: mixed cell");
        };
        dst[at] = u8::from(value.f_bool);
        at += 1;
        dst[at..at + 4].copy_from_slice(&(value.f_int32 as u32).to_le_bytes());
        at += 4;
        dst[at..at + 8].copy_from_slice(&(value.f_int64 as u64).to_le_bytes());
        at += 8;
        dst[at..at + 8].copy_from_slice(&value.f_float64.to_bits().to_le_bytes());
        at += 8;
        dst[at..at + 4].copy_from_slice(&(value.f_string.len() as u32).to_le_bytes());
        at += 4;
        dst[at..at + value.f_string.len()].copy_from_slice(value.f_string.as_bytes());
        at += value.f_string.len();
        dst[at] = u8::from(value.f_bool_2);
        at += 1;
        dst[at..at + 4].copy_from_slice(&(value.f_int32_2 as u32).to_le_bytes());
        at += 4;
        dst[at..at + 4].copy_from_slice(&(value.f_string_2.len() as u32).to_le_bytes());
        at += 4;
        dst[at..at + value.f_string_2.len()].copy_from_slice(value.f_string_2.as_bytes());
        at += value.f_string_2.len();
    }
    if at != total {
        bail!("gld-kiln: message batch length");
    }
    Ok(())
}

fn read_document(reader: &mut Reader<'_>) -> Result<Document> {
    let id = read_string(reader)?;
    let status = reader.i32().map_err(err)?;
    let meta = DocumentMeta {
        region: read_string(reader)?,
        version: reader.i32().map_err(err)?,
    };
    let n = reader.list_count(16).map_err(err)? as usize;
    let mut items = Vec::with_capacity(n);
    for _ in 0..n {
        items.push(DocumentItem {
            sku: read_string(reader)?,
            qty: reader.i32().map_err(err)?,
            price_minor: reader.i64().map_err(err)?,
        });
    }
    Ok(Document {
        id,
        status,
        meta,
        items,
    })
}

fn read_telemetry(reader: &mut Reader<'_>) -> Result<Telemetry> {
    Ok(Telemetry {
        source: read_string(reader)?,
        ts: reader.i64().map_err(err)?,
        tags: read_string_list(reader)?,
        values: read_f64s(reader)?,
    })
}

fn read_strings(reader: &mut Reader<'_>) -> Result<Strings> {
    Ok(Strings {
        items: read_string_list(reader)?,
    })
}

fn read_event(reader: &mut Reader<'_>) -> Result<Event> {
    let event_id = read_string(reader)?;
    let event_type = read_string(reader)?;
    let occurred_at = reader.i64().map_err(err)?;
    let producer = read_string(reader)?;
    let n = reader.list_count(8).map_err(err)? as usize;
    let mut attrs = Vec::with_capacity(n);
    for _ in 0..n {
        attrs.push(EventAttr {
            key: read_string(reader)?,
            value: read_string(reader)?,
        });
    }
    Ok(Event {
        event_id,
        event_type,
        occurred_at,
        producer,
        attrs,
    })
}

fn read_prompt(reader: &mut Reader<'_>) -> Result<Prompt> {
    Ok(Prompt {
        batch: reader.i32().map_err(err)?,
        seq: reader.i32().map_err(err)?,
        input_ids: read_i64s(reader)?,
        attention_mask: read_i64s(reader)?,
        position_ids: read_i64s(reader)?,
    })
}

fn read_shard(reader: &mut Reader<'_>) -> Result<Shard> {
    Ok(Shard {
        vocab: reader.i32().map_err(err)?,
        hidden: reader.i32().map_err(err)?,
        ffn: reader.i32().map_err(err)?,
        tok_emb: read_f32s(reader)?,
        attn: read_f32s(reader)?,
        ffn_weight: read_f32s(reader)?,
        norm: read_f32s(reader)?,
    })
}

fn read_request(reader: &mut Reader<'_>) -> Result<InferenceRequest> {
    Ok(InferenceRequest {
        request_id: reader.i64().map_err(err)?,
        model: read_string(reader)?,
        temperature: reader.f32().map_err(err)?,
        inputs: read_prompt(reader)?,
    })
}

fn read_tensor(reader: &mut Reader<'_>) -> Result<TensorMatrix> {
    let rows = reader.i32().map_err(err)?;
    let cols = reader.i32().map_err(err)?;
    Ok(TensorMatrix::owned(rows, cols, read_f32s(reader)?))
}

/// Rows, cols, count, then the f32 body. The body is a pointer into `data`.
fn read_tensor_view(data: &[u8]) -> Result<TensorMatrix> {
    let mut reader = Reader::new(data);
    let rows = reader.i32().map_err(err)?;
    let cols = reader.i32().map_err(err)?;
    let n = reader.list_count(4).map_err(err)? as usize;
    let payload = read_body(&mut reader, n, 4)?;
    reader.finish().map_err(err)?;
    Ok(TensorMatrix::borrowed(rows, cols, payload))
}

fn read_one(kind: &str, reader: &mut Reader<'_>) -> Result<Fixture> {
    Ok(match kind {
        "message" => bail!("gld-kiln: message is read by read_message_one"),
        "document" => Fixture::Document(read_document(reader)?),
        "telemetry" => Fixture::Telemetry(read_telemetry(reader)?),
        "strings" => Fixture::Strings(read_strings(reader)?),
        "event" => Fixture::Event(read_event(reader)?),
        "tensor" => Fixture::Tensor(read_tensor(reader)?),
        "prompt" => Fixture::Prompt(read_prompt(reader)?),
        "shard" => Fixture::Shard(read_shard(reader)?),
        "request" => Fixture::Request(read_request(reader)?),
        other => bail!("gld-kiln: unsupported {other}"),
    })
}

/// Minimum encoded size of one struct. Used so a hostile list count fails
/// before `Vec` reserves element storage.
fn min_struct(kind: &str) -> u64 {
    match kind {
        // bool + i32 + i64 + f64 + str + bool + i32 + str
        "message" => 34,
        // str + i32 + (str + i32) + list count
        "document" => 20,
        // str + i64 + list<str> count + list<f64> count
        "telemetry" => 20,
        "strings" => 4,
        // three str + i64 + list count
        "event" => 24,
        _ => 1,
    }
}

pub struct KilnSer {
    kind: &'static str,
    batch: bool,
}

impl Default for KilnSer {
    fn default() -> Self {
        Self {
            kind: "message",
            batch: false,
        }
    }
}

impl KilnSer {
    fn write_prepared(&self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        if self.batch && self.kind == "message" {
            return write_message_list(fixtures, out);
        }
        if self.batch {
            write_count(out, fixtures.len(), DEFAULT_CAP).map_err(err)?;
            for fx in fixtures {
                if fx.name() != self.kind {
                    bail!("gld-kiln: mixed cell");
                }
                write_one(out, fx)?;
            }
            return Ok(());
        }
        if fixtures.len() != 1 {
            bail!("gld-kiln: N>1 requires prepare_many so the schema is a list");
        }
        write_one(out, &fixtures[0])
    }
}

impl BenchSerializer for KilnSer {
    fn name(&self) -> &'static str {
        "gld-kiln"
    }

    fn version(&self) -> &'static str {
        super::ver("gld-kiln")
    }

    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }

    fn native_kind(&self) -> NativeKind {
        NativeKind::Message
    }

    fn supports(&self, test_data_name: &str) -> bool {
        SUITE.contains(&test_data_name) || TENSOR.contains(&test_data_name)
    }

    /// N>1 is one list payload, not the harness length-prefix frame.
    fn one_cell_payload(&self) -> bool {
        self.batch
    }

    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.prepare_many(std::slice::from_ref(fixture))
    }

    fn prepare_many(&mut self, fixtures: &[Fixture]) -> Result<()> {
        if fixtures.is_empty() {
            bail!("gld-kiln: empty cell");
        }
        let kind = fixtures[0].name();
        if !self.supports(kind) {
            bail!("gld-kiln: unsupported {kind}");
        }
        if kind == "tensor_view" && fixtures.len() != 1 {
            bail!("gld-kiln: tensor_view is one borrowed matrix");
        }
        if fixtures.iter().any(|fx| fx.name() != kind) {
            bail!("gld-kiln: mixed cell");
        }
        self.kind = kind;
        self.batch = fixtures.len() > 1;
        Ok(())
    }

    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        if self.batch {
            bail!("gld-kiln: batch cell is one list; call serialize_fixtures");
        }
        self.write_prepared(std::slice::from_ref(fixture), out)
    }

    fn serialize_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        if self.batch {
            if fixtures.len() <= 1 {
                bail!("gld-kiln: prepared a list but cell has {}", fixtures.len());
            }
            return self.write_prepared(fixtures, out);
        }
        if fixtures.len() != 1 {
            bail!("gld-kiln: N>1 requires prepare_many so the schema is a list");
        }
        self.serialize_into(&fixtures[0], out)
    }

    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        if self.kind == "tensor_view" {
            bail!("gld-kiln: tensor_view borrows the bytes buffer");
        }
        let mut data = Vec::new();
        r.read_to_end(&mut data)?;
        self.deserialize_bytes(&data)
    }

    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        if self.kind == "message" {
            return if self.batch {
                read_message_list(data)
            } else {
                read_message_one(data)
            };
        }
        if self.kind == "tensor_view" {
            if self.batch {
                bail!("gld-kiln: tensor_view batch is not a borrowed matrix");
            }
            return Ok(Fixture::TensorView(read_tensor_view(data)?));
        }
        let mut reader = Reader::new(data);
        if self.batch {
            let n = reader.list_count(min_struct(self.kind)).map_err(err)? as usize;
            let mut rows = Vec::with_capacity(n);
            for _ in 0..n {
                rows.push(read_one(self.kind, &mut reader)?);
            }
            reader.finish().map_err(err)?;
            return Ok(Fixture::Rows(rows));
        }
        let value = read_one(self.kind, &mut reader)?;
        reader.finish().map_err(err)?;
        Ok(value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::data::{check_cell_fidelity, make_one, TypeConfig};
    use kiln::{encode, Schema, Value};
    use std::time::Instant;

    fn message_value(value: &Message) -> Value<'static> {
        Value::Struct(vec![
            Value::Bool(value.f_bool),
            Value::I32(value.f_int32),
            Value::I64(value.f_int64),
            Value::from_f64(value.f_float64),
            Value::str(value.f_string.clone()),
            Value::Bool(value.f_bool_2),
            Value::I32(value.f_int32_2),
            Value::str(value.f_string_2.clone()),
        ])
    }

    fn message_schema() -> Schema {
        Schema::struct_fields([
            ("f_bool", Schema::Bool),
            ("f_int32", Schema::I32),
            ("f_int64", Schema::I64),
            ("f_float64", Schema::F64),
            ("f_string", Schema::Str),
            ("f_bool_2", Schema::Bool),
            ("f_int32_2", Schema::I32),
            ("f_string_2", Schema::Str),
        ])
    }

    #[test]
    fn message_bytes_match_the_library_encoder() {
        let one = make_one("message", 42, 0, &TypeConfig::default()).unwrap();
        let mut ser = KilnSer::default();
        ser.prepare(&one).unwrap();
        let bytes = ser.serialize_bytes(&one).unwrap();
        let Fixture::Message(message) = &one else {
            panic!("{}", one.name());
        };
        let library = encode(&message_schema(), &message_value(message)).unwrap();
        assert_eq!(bytes, library);

        let many = vec![one.clone(), one.clone()];
        let mut batch = KilnSer::default();
        batch.prepare_many(&many).unwrap();
        let mut listed = Vec::new();
        batch.serialize_fixtures(&many, &mut listed).unwrap();
        let library_list = encode(
            &Schema::list(message_schema()),
            &Value::List(vec![message_value(message), message_value(message)]),
        )
        .unwrap();
        assert_eq!(listed, library_list);
    }

    #[test]
    fn suite_roundtrip_one_and_batch_list() {
        let cfg = TypeConfig::default();
        for kind in SUITE {
            let one = make_one(kind, 42, 0, &cfg).unwrap();
            let mut ser = KilnSer::default();
            assert!(ser.supports(kind));
            ser.prepare(&one).unwrap();
            assert!(!ser.one_cell_payload());
            let bytes = ser.serialize_bytes(&one).unwrap();
            let got = ser.deserialize_bytes(&bytes).unwrap();
            check_cell_fidelity(kind, std::slice::from_ref(&one), std::slice::from_ref(&got))
                .unwrap();

            let many: Vec<_> = (0..100)
                .map(|i| make_one(kind, 9, i, &cfg).unwrap())
                .collect();
            let mut ser = KilnSer::default();
            ser.prepare_many(&many).unwrap();
            assert!(ser.one_cell_payload());
            let mut buf = Vec::new();
            ser.serialize_fixtures(&many, &mut buf).unwrap();
            let got = ser.deserialize_bytes(&buf).unwrap();
            check_cell_fidelity(kind, &many, std::slice::from_ref(&got)).unwrap();
            let cap = buf.capacity();
            buf.clear();
            ser.serialize_fixtures(&many, &mut buf).unwrap();
            assert!(buf.capacity() >= cap);
            assert!(buf.len() > 4);
        }
        let ser = KilnSer::default();
        assert!(!ser.supports("graph"));
        assert!(!ser.supports("table"));
        assert!(!ser.supports("grid"));
        assert!(ser.supports("tensor"));
        assert!(ser.supports("tensor_view"));
        assert!(ser.supports("prompt"));
        assert!(ser.supports("shard"));
        assert!(ser.supports("request"));
    }

    fn small_cfg(kind: &str) -> TypeConfig {
        let value = match kind {
            "tensor" | "tensor_view" => serde_json::json!({"rows": 4, "cols": 4}),
            "prompt" | "request" => serde_json::json!({
                "batch": 2,
                "seq": 4,
                "vocab": 32,
                "string_len": {"min": 4, "max": 6}
            }),
            "shard" => serde_json::json!({"vocab": 4, "hidden": 3, "ffn": 5}),
            _ => serde_json::json!({}),
        };
        TypeConfig::from_value(value)
    }

    #[test]
    fn tensor_set_roundtrip_and_view_borrows() {
        for kind in TENSOR {
            let one = make_one(kind, 7, 0, &small_cfg(kind)).unwrap();
            let mut ser = KilnSer::default();
            ser.prepare(&one).unwrap();
            let bytes = ser.serialize_bytes(&one).unwrap();
            let got = ser.deserialize_bytes(&bytes).unwrap();
            check_cell_fidelity(kind, std::slice::from_ref(&one), std::slice::from_ref(&got))
                .unwrap();
            if *kind == "tensor_view" {
                let Fixture::TensorView(view) = &got else {
                    panic!("{}", got.name());
                };
                assert!(view.values.is_borrowed());
                assert!(view.values.borrowed_in(&bytes));
                assert_eq!(view.values.bit(0), 0x8000_0000);
                assert_eq!(view.values.bit(1), 0x7fc0_0000);
            }
            if *kind == "tensor" {
                assert_eq!(bytes.len(), 12 + 16 * 4);
                let Fixture::Tensor(matrix) = &got else {
                    panic!("{}", got.name());
                };
                assert!(!matrix.values.is_borrowed());
                assert!(!matrix.values.borrowed_in(&bytes));
            }
        }
    }

    #[test]
    fn catalog_tensor_wire_is_4194316() {
        let cfg = TypeConfig::default();
        let one = make_one("tensor", 1, 0, &cfg).unwrap();
        let mut ser = KilnSer::default();
        ser.prepare(&one).unwrap();
        let bytes = ser.serialize_bytes(&one).unwrap();
        assert_eq!(bytes.len(), 4_194_316);
        let got = ser.deserialize_bytes(&bytes).unwrap();
        check_cell_fidelity(
            "tensor",
            std::slice::from_ref(&one),
            std::slice::from_ref(&got),
        )
        .unwrap();
        let view = make_one("tensor_view", 1, 0, &cfg).unwrap();
        let mut view_ser = KilnSer::default();
        view_ser.prepare(&view).unwrap();
        let view_bytes = view_ser.serialize_bytes(&view).unwrap();
        assert_eq!(view_bytes, bytes);
        let borrowed = view_ser.deserialize_bytes(&view_bytes).unwrap();
        check_cell_fidelity(
            "tensor_view",
            std::slice::from_ref(&view),
            std::slice::from_ref(&borrowed),
        )
        .unwrap();
        let Fixture::TensorView(matrix) = &borrowed else {
            panic!("{}", borrowed.name());
        };
        assert!(matrix.values.borrowed_in(&view_bytes));
        assert_eq!(matrix.values.len(), 1024 * 1024);
    }

    #[test]
    fn catalog_tensor_copy_is_near_a_memcpy() {
        let cfg = TypeConfig::default();
        let one = make_one("tensor", 1, 0, &cfg).unwrap();
        let mut ser = KilnSer::default();
        ser.prepare(&one).unwrap();
        let mut buf = Vec::new();
        ser.serialize_into(&one, &mut buf).unwrap();
        let mut best_ser = u128::MAX;
        let mut best_de = u128::MAX;
        for _ in 0..5 {
            buf.clear();
            let t0 = Instant::now();
            ser.serialize_into(&one, &mut buf).unwrap();
            let ser_ns = t0.elapsed().as_nanos();
            let t1 = Instant::now();
            let got = ser.deserialize_bytes(&buf).unwrap();
            let de_ns = t1.elapsed().as_nanos();
            std::hint::black_box(&got);
            best_ser = best_ser.min(ser_ns);
            best_de = best_de.min(de_ns);
        }
        // Mojo on this host copies the 4 MiB matrix in about 0.25–0.35 ms.
        // The old Value-per-float read was about 38 ms. Stay under 2 ms so a
        // busy machine can still tell a memcpy from that graph.
        assert!(best_ser < 2_000_000, "ser {best_ser}");
        assert!(best_de < 2_000_000, "deser {best_de}");
    }

    fn best_roundtrip(kind: &str, cfg: &TypeConfig) -> (u128, u128, usize) {
        let one = make_one(kind, 1, 0, cfg).unwrap();
        let mut ser = KilnSer::default();
        ser.prepare(&one).unwrap();
        let mut buf = Vec::new();
        ser.serialize_into(&one, &mut buf).unwrap();
        let mut best_ser = u128::MAX;
        let mut best_de = u128::MAX;
        for _ in 0..20 {
            buf.clear();
            let t0 = Instant::now();
            ser.serialize_into(&one, &mut buf).unwrap();
            let ser_ns = t0.elapsed().as_nanos();
            let t1 = Instant::now();
            let got = ser.deserialize_bytes(&buf).unwrap();
            let de_ns = t1.elapsed().as_nanos();
            std::hint::black_box(&got);
            best_ser = best_ser.min(ser_ns);
            best_de = best_de.min(de_ns);
        }
        (best_ser, best_de, buf.len())
    }

    #[test]
    fn direct_path_beats_the_value_tree_on_suite_and_shard() {
        if cfg!(debug_assertions) {
            return;
        }
        let cfg = TypeConfig::default();
        let (ser_ns, de_ns, _) = best_roundtrip("message", &cfg);
        // Published Value-tree read was about 313 ns.
        assert!(de_ns < 1_000, "message deser {de_ns} ser {ser_ns}");
        let (ser_ns, de_ns, _) = best_roundtrip("shard", &cfg);
        // Published Value-tree read of the shard weights was about 10 ms.
        assert!(de_ns < 2_000_000, "shard deser {de_ns} ser {ser_ns}");
    }
}
