#include "bench/types.hpp"
#include "bench/fixture.hpp"

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <limits>
#include <memory>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace bench {
namespace {

int32_t clamp_i32_hi(int32_t hi) {
  constexpr int32_t kMax = 2147483647;
  return hi > kMax ? kMax : hi;
}

void default_slen(const std::string& type_id, int& smin, int& smax) {
  if (type_id == "graph") {
    smin = 8;
    smax = 16;
    return;
  }
  smin = 3;
  if (type_id == "telemetry") {
    smax = 10;
  } else if (type_id == "document" || type_id == "nested_table" || type_id == "event" ||
             type_id == "signal") {
    smax = 12;
  } else {
    smax = 16;
  }
}

void resolve_slen(const std::string& type_id, const TypeConfig& cfg, int& smin, int& smax) {
  if (cfg.string_len_min >= 0 && cfg.string_len_max >= 0) {
    smin = cfg.string_len_min;
    smax = cfg.string_len_max;
    return;
  }
  default_slen(type_id, smin, smax);
}

void resolve_irange(const TypeConfig& cfg, int32_t& lo, int32_t& hi) {
  if (cfg.has_int_range) {
    lo = cfg.int_range_min;
    hi = cfg.int_range_max;
  } else {
    lo = 0;
    hi = 1000000;
  }
}

double resolve_dup(const std::string& type_id, const TypeConfig& cfg) {
  if (cfg.duplication >= 0.0) return cfg.duplication;
  if (type_id == "table" || type_id == "table_project") return 0.5;
  if (type_id == "strings") return 0.1;
  return 0.0;
}

int resolve_children(const std::string& type_id, const TypeConfig& cfg) {
  if (cfg.children >= 0) return cfg.children;
  if (type_id == "nested_table") return 4;
  return 8;
}

int resolve_group(const TypeConfig& cfg) { return cfg.group_count >= 0 ? cfg.group_count : 4; }

int resolve_or(int v, int def) { return v >= 0 ? v : def; }

int dim_or(int v, int def) { return v > 0 ? v : def; }

size_t mul_count(int a, int b, const char* what) {
  const int64_t n = static_cast<int64_t>(a) * static_cast<int64_t>(b);
  if (a < 1 || b < 1 || n > static_cast<int64_t>(std::numeric_limits<int32_t>::max())) {
    throw std::runtime_error(std::string(what) + " shape");
  }
  return static_cast<size_t>(n);
}

std::vector<float> f32_fill(Rng& r, size_t count, bool pin) {
  std::vector<float> values(count);
  for (size_t i = 0; i < count; ++i) values[i] = static_cast<float>(r.next_f64());
  if (pin) {
    if (count < 2) throw std::runtime_error("tensor needs at least 2 elements");
    values[0] = f32_from_bits(0x80000000u);
    values[1] = f32_from_bits(0x7fc00000u);
  }
  return values;
}

TensorMatrix make_tensor(Rng& r, const TypeConfig& cfg) {
  const int rows = dim_or(cfg.rows, 1024);
  const int cols = dim_or(cfg.cols, 1024);
  const size_t n = mul_count(rows, cols, "tensor");
  if (n < 2) throw std::runtime_error("tensor needs at least 2 elements");
  TensorMatrix m;
  m.rows = rows;
  m.cols = cols;
  m.values = f32_fill(r, n, true);
  return m;
}

Prompt make_prompt(Rng& r, const TypeConfig& cfg) {
  const int batch = dim_or(cfg.batch, 4);
  const int seq = dim_or(cfg.seq, 256);
  const int vocab = dim_or(cfg.vocab, 32000);
  if (vocab < 2) throw std::runtime_error("prompt vocab");
  const size_t n = mul_count(batch, seq, "prompt");
  Prompt p;
  p.batch = batch;
  p.seq = seq;
  p.input_ids.reserve(n);
  p.attention_mask.reserve(n);
  p.position_ids.reserve(n);
  const int lo = std::max(1, seq / 2);
  for (int row = 0; row < batch; ++row) {
    const int content = r.next_int(lo, seq);
    for (int col = 0; col < seq; ++col) {
      if (col < content) {
        p.input_ids.push_back(r.next_int(1, vocab - 1));
        p.attention_mask.push_back(1);
      } else {
        p.input_ids.push_back(0);
        p.attention_mask.push_back(0);
      }
      p.position_ids.push_back(col);
    }
  }
  return p;
}

Shard make_shard(Rng& r, const TypeConfig& cfg) {
  const int vocab = dim_or(cfg.vocab, 1024);
  const int hidden = dim_or(cfg.hidden, 256);
  const int ffn = dim_or(cfg.ffn, 512);
  Shard s;
  s.vocab = vocab;
  s.hidden = hidden;
  s.ffn = ffn;
  s.tok_emb = f32_fill(r, mul_count(vocab, hidden, "shard tok_emb"), false);
  s.attn = f32_fill(r, mul_count(hidden, hidden, "shard attn"), false);
  s.ffn_weight = f32_fill(r, mul_count(ffn, hidden, "shard ffn"), false);
  s.norm = f32_fill(r, static_cast<size_t>(hidden), false);
  return s;
}

Request make_request(Rng& r, const TypeConfig& cfg, const std::string& type_id) {
  int smin = 3;
  int smax = 16;
  resolve_slen(type_id, cfg, smin, smax);
  Request q;
  q.request_id = r.next_int(1, 1000000000);
  q.model = r.word(smin, smax);
  q.temperature = static_cast<float>(r.next_f64() * 2.0);
  q.inputs = make_prompt(r, cfg);
  return q;
}

// Call order is the cross-language contract: regions, orders, names, then the ring.
Book make_book(Rng& r, int order_count, int region_count, int ring_size, int smin, int smax) {
  if (region_count < 1) throw std::runtime_error("region_count must be >= 1");
  if (ring_size < 1) throw std::runtime_error("ring_size must be >= 1");
  Book b;
  b.regions.reserve(static_cast<size_t>(region_count));
  std::vector<Region*> regs;
  regs.reserve(static_cast<size_t>(region_count));
  for (int i = 0; i < region_count; ++i) {
    auto reg = std::make_unique<Region>();
    reg->code = r.word(smin, smax);
    reg->note = r.word(64, 64);
    reg->version = r.next_int(1, 10);
    regs.push_back(reg.get());
    b.regions.push_back(std::move(reg));
  }
  b.orders.reserve(static_cast<size_t>(order_count));
  for (int i = 0; i < order_count; ++i) {
    Order o;
    o.sku = r.word(smin, smax);
    o.qty = r.next_int(1, 100);
    o.region = regs[static_cast<size_t>(i % region_count)];
    b.orders.push_back(std::move(o));
  }
  std::vector<Person*> ring;
  ring.reserve(static_cast<size_t>(ring_size));
  b.people.reserve(static_cast<size_t>(ring_size));
  for (int i = 0; i < ring_size; ++i) {
    auto person = std::make_unique<Person>();
    person->name = r.word(smin, smax);
    ring.push_back(person.get());
    b.people.push_back(std::move(person));
  }
  for (int i = 0; i < ring_size; ++i) {
    b.people[static_cast<size_t>(i)]->next = ring[static_cast<size_t>((i + 1) % ring_size)];
  }
  return b;
}

std::vector<std::string> shared_vocab(uint64_t seed, const std::string& type_id, int smin, int smax) {
  Rng vocab(mix_seed(seed, type_id + "#vocab", 0));
  std::vector<std::string> words;
  words.reserve(32);
  for (int i = 0; i < 32; ++i) words.push_back(vocab.word(smin, smax));
  return words;
}

std::string pick_word(Rng& r, const std::vector<std::string>& vocab, double dup, int smin, int smax) {
  if (!vocab.empty() && r.next_f64() < dup) {
    return vocab[static_cast<size_t>(r.next_int(0, static_cast<int32_t>(vocab.size()) - 1))];
  }
  return r.word(smin, smax);
}

Table make_table(Rng& r, int32_t lo, int32_t hi, int smin, int smax, double dup,
                 const std::vector<std::string>& vocab) {
  Table t;
  for (int i = 0; i < 16; ++i) t.f_float[i] = r.next_f64() * 1000.0;
  for (int i = 0; i < 4; ++i) t.f_int[i] = r.next_int(lo, hi);
  t.f_str_0 = pick_word(r, vocab, dup, smin, smax);
  t.f_str_1 = pick_word(r, vocab, dup, smin, smax);
  return t;
}

NestedRow make_nested(Rng& r, int children, int smin, int smax) {
  NestedRow row;
  row.items.reserve(static_cast<size_t>(children));
  for (int i = 0; i < children; ++i) {
    NestedItem it;
    it.sku = r.word(smin, smax);
    it.qty = r.next_int(1, 100);
    it.price_minor = r.next_int(0, 100000);
    row.items.push_back(std::move(it));
  }
  row.id = r.word(8, 12);
  row.status = r.next_int(0, 5);
  row.meta.region = r.word(2, 4);
  row.meta.version = r.next_int(1, 10);
  return row;
}

Signal make_signal(Rng& r, int group_count, int smin, int smax) {
  Signal s;
  s.legs.reserve(static_cast<size_t>(group_count));
  for (int i = 0; i < group_count; ++i) {
    SignalLeg leg;
    leg.leg_id = r.next_int(0, 1000000);
    leg.leg_qty = r.next_int(0, 10000);
    leg.leg_pad = 0;
    s.legs.push_back(leg);
  }
  s.seq = r.next_int(0, 1000000000);
  s.ts = kBaseTsMs + r.next_int(0, 86400000);
  s.price_mantissa = r.next_int(0, 1000000000);
  s.qty = r.next_int(0, 10000);
  s.flags = r.next_int(0, 65535);
  s.symbol = r.word(smin, smax);
  s.venue = r.word(smin, smax);
  return s;
}

Value make_one(const std::string& type_id, const TypeConfig& cfg, uint64_t seed, int idx) {
  // tensor_view is the same matrix as tensor for this seed and shape.
  if (type_id == "tensor" || type_id == "tensor_view") {
    Rng r(mix_seed(seed, "tensor", idx));
    return make_tensor(r, cfg);
  }
  Rng r(mix_seed(seed, type_id, idx));
  int smin = 3;
  int smax = 16;
  resolve_slen(type_id, cfg, smin, smax);
  if (type_id == "message") {
    int32_t lo = 0;
    int32_t hi = 1000000;
    resolve_irange(cfg, lo, hi);
    return make_message(r, lo, hi, smin, smax);
  }
  if (type_id == "document") return make_document(r, resolve_children(type_id, cfg), smin, smax);
  if (type_id == "telemetry") return make_telemetry(r, cfg.points, cfg.tag_count, smin, smax);
  if (type_id == "strings") return make_strings(r, cfg.count, smin, smax, resolve_dup(type_id, cfg));
  if (type_id == "event") return make_event(r, cfg.attr_count, smin, smax);
  if (type_id == "table" || type_id == "table_project") {
    int32_t lo = 0;
    int32_t hi = 1000000;
    resolve_irange(cfg, lo, hi);
    auto vocab = shared_vocab(seed, type_id, smin, smax);
    return make_table(r, lo, hi, smin, smax, resolve_dup(type_id, cfg), vocab);
  }
  if (type_id == "nested_table") return make_nested(r, resolve_children(type_id, cfg), smin, smax);
  if (type_id == "signal") return make_signal(r, resolve_group(cfg), smin, smax);
  if (type_id == "graph") {
    return make_book(r, resolve_or(cfg.order_count, 32), resolve_or(cfg.region_count, 4),
                     resolve_or(cfg.ring_size, 8), smin, smax);
  }
  if (type_id == "grid" || type_id == "grid_window") {
    const bool window = type_id == "grid_window";
    const int nx = cfg.nx > 0 ? cfg.nx : 512;
    const int ny = cfg.ny > 0 ? cfg.ny : 512;
    Grid grid;
    grid.nx = nx;
    grid.ny = ny;
    if (window) {
      grid.x0 = cfg.x0;
      grid.y0 = cfg.y0;
      grid.wx = cfg.wx > 0 ? cfg.wx : 256;
      grid.wy = cfg.wy > 0 ? cfg.wy : 128;
    }
    grid.values.resize(static_cast<size_t>(nx) * static_cast<size_t>(ny));
    for (int y = 0; y < ny; ++y) {
      for (int x = 0; x < nx; ++x)
        grid.values[static_cast<size_t>(y) * static_cast<size_t>(nx) + static_cast<size_t>(x)] =
            r.next_f64();
    }
    return grid;
  }
  if (type_id == "prompt") return make_prompt(r, cfg);
  if (type_id == "shard") return make_shard(r, cfg);
  if (type_id == "request") return make_request(r, cfg, type_id);
  throw std::runtime_error("unknown type_id: " + type_id);
}

template <typename T>
std::vector<T> many_of(const std::string& type_id, const TypeConfig& cfg, uint64_t seed, int n) {
  std::vector<T> v;
  v.reserve(static_cast<size_t>(n));
  for (int i = 0; i < n; ++i) v.push_back(std::get<T>(make_one(type_id, cfg, seed, i)));
  return v;
}

}  // namespace

Message make_message(Rng& r, int32_t lo, int32_t hi, int smin, int smax) {
  const int32_t hi32 = clamp_i32_hi(hi);
  return Message{r.next_bool(),
                 r.next_int(lo, hi32),
                 static_cast<int64_t>(r.next_int(lo, hi)),
                 r.next_f64() * 1000.0,
                 r.word(smin, smax),
                 r.next_bool(),
                 r.next_int(lo, hi32),
                 r.word(smin, smax)};
}

Document make_document(Rng& r, int children, int smin, int smax) {
  Document d;
  d.id = r.word(8, 12);
  d.status = r.next_int(0, 5);
  d.meta = DocumentMeta{r.word(2, 4), r.next_int(1, 10)};
  d.items.reserve(static_cast<size_t>(children));
  for (int i = 0; i < children; ++i) {
    d.items.push_back(DocumentItem{r.word(smin, smax), r.next_int(1, 100),
                                   static_cast<int64_t>(r.next_int(0, 100000))});
  }
  return d;
}

Telemetry make_telemetry(Rng& r, int points, int tag_count, int smin, int smax) {
  Telemetry t;
  t.source = r.word(smin, smax);
  t.ts = kBaseTsMs + r.next_int(0, 86400000);
  t.tags.reserve(static_cast<size_t>(tag_count));
  for (int i = 0; i < tag_count; ++i) t.tags.push_back(r.word(smin, smax));
  t.values.reserve(static_cast<size_t>(points));
  for (int i = 0; i < points; ++i) t.values.push_back(r.next_f64() * 100.0);
  return t;
}

Strings make_strings(Rng& r, int count, int smin, int smax, double duplication) {
  Strings s;
  s.items.reserve(static_cast<size_t>(count));
  std::vector<std::string> pool;
  for (int i = 0; i < count; ++i) {
    if (!pool.empty() && r.next_f64() < duplication) {
      s.items.push_back(pool[static_cast<size_t>(r.next_int(0, static_cast<int32_t>(pool.size()) - 1))]);
    } else {
      auto w = r.word(smin, smax);
      pool.push_back(w);
      s.items.push_back(std::move(w));
    }
  }
  return s;
}

Event make_event(Rng& r, int attr_count, int smin, int smax) {
  Event e;
  e.event_id = r.word(8, 12);
  e.event_type = r.word(smin, smax);
  e.occurred_at = kBaseTsMs + r.next_int(0, 86400000);
  e.producer = r.word(smin, smax);
  e.attrs.reserve(static_cast<size_t>(attr_count));
  for (int i = 0; i < attr_count; ++i) {
    e.attrs.push_back(EventAttr{r.word(smin, smax), r.word(smin, smax)});
  }
  return e;
}

Fixture make_fixture(const std::string& type_id, const TypeConfig& cfg, uint64_t seed,
                     int instance_count, const std::string& type_config_hash) {
  Fixture fx;
  fx.type_id = type_id;
  fx.instance_count = instance_count < 1 ? 1 : instance_count;
  fx.type_config_hash = type_config_hash;
  if (fx.instance_count == 1) {
    fx.value = make_one(type_id, cfg, seed, 0);
    return fx;
  }
  if (type_id == "message") fx.value = many_of<Message>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "document") fx.value = many_of<Document>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "telemetry")
    fx.value = many_of<Telemetry>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "strings") fx.value = many_of<Strings>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "event") fx.value = many_of<Event>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "table" || type_id == "table_project")
    fx.value = many_of<Table>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "nested_table")
    fx.value = many_of<NestedRow>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "signal") fx.value = many_of<Signal>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "graph") fx.value = many_of<Book>(type_id, cfg, seed, fx.instance_count);
  else if (type_id == "grid" || type_id == "grid_window")
    throw std::runtime_error("grid N must be 1");
  else if (type_id == "tensor" || type_id == "tensor_view" || type_id == "prompt" ||
           type_id == "shard" || type_id == "request")
    throw std::runtime_error(type_id + " N must be 1");
  else
    throw std::runtime_error("unknown type_id: " + type_id);
  return fx;
}

Book::Book(const Book& other) { *this = other; }

Book& Book::operator=(const Book& other) {
  if (this == &other) return *this;
  std::unordered_map<const Region*, Region*> rmap;
  std::vector<std::unique_ptr<Region>> regs;
  regs.reserve(other.regions.size());
  auto region_for = [&](const Region* src) -> Region* {
    if (src == nullptr) return nullptr;
    const auto it = rmap.find(src);
    if (it != rmap.end()) return it->second;
    auto node = std::make_unique<Region>(*src);
    Region* raw = node.get();
    rmap.emplace(src, raw);
    regs.push_back(std::move(node));
    return raw;
  };
  for (const auto& region : other.regions) (void)region_for(region.get());

  std::unordered_map<const Person*, Person*> pmap;
  std::vector<std::unique_ptr<Person>> owned;
  owned.reserve(other.people.size());
  for (const auto& person : other.people) {
    auto node = std::make_unique<Person>();
    node->name = person->name;
    pmap.emplace(person.get(), node.get());
    owned.push_back(std::move(node));
  }
  auto person_for = [&](const Person* src) -> Person* {
    if (src == nullptr) return nullptr;
    const auto it = pmap.find(src);
    if (it != pmap.end()) return it->second;
    auto node = std::make_unique<Person>();
    node->name = src->name;
    Person* raw = node.get();
    pmap.emplace(src, raw);
    owned.push_back(std::move(node));
    return raw;
  };
  for (size_t i = 0; i < other.people.size(); ++i) {
    owned[i]->next = person_for(other.people[i]->next);
  }

  std::vector<Order> copied;
  copied.reserve(other.orders.size());
  for (const Order& order : other.orders) {
    Order o;
    o.sku = order.sku;
    o.qty = order.qty;
    o.region = region_for(order.region);
    copied.push_back(std::move(o));
  }
  regions = std::move(regs);
  people = std::move(owned);
  orders = std::move(copied);
  return *this;
}

namespace {

struct IdMemo {
  std::unordered_map<const void*, int> left;
  std::unordered_map<const void*, int> right;
  int n = 0;

  // fresh means the pair is new and its fields still have to be compared.
  bool bind(const void* a, const void* b, bool& fresh) {
    const auto ia = left.find(a);
    const auto ib = right.find(b);
    if (ia != left.end() || ib != right.end()) {
      fresh = false;
      return ia != left.end() && ib != right.end() && ia->second == ib->second;
    }
    const int token = n++;
    left.emplace(a, token);
    right.emplace(b, token);
    fresh = true;
    return true;
  }
};

bool pair_region(const Region* a, const Region* b, IdMemo& memo) {
  if (a == nullptr || b == nullptr) return a == b;
  bool fresh = false;
  if (!memo.bind(a, b, fresh)) return false;
  if (!fresh) return true;
  return a->code == b->code && a->note == b->note && a->version == b->version;
}

bool pair_person(const Person* a, const Person* b, IdMemo& memo) {
  if (a == nullptr || b == nullptr) return a == b;
  bool fresh = false;
  if (!memo.bind(a, b, fresh)) return false;
  if (!fresh) return true;
  return a->name == b->name && pair_person(a->next, b->next, memo);
}

bool pair_order(const Order& a, const Order& b, IdMemo& memo) {
  return a.sku == b.sku && a.qty == b.qty && pair_region(a.region, b.region, memo);
}

bool books_equal(const Book& a, const Book& b) {
  if (a.orders.size() != b.orders.size() || a.people.size() != b.people.size()) return false;
  IdMemo memo;
  for (size_t i = 0; i < a.orders.size(); ++i) {
    if (!pair_order(a.orders[i], b.orders[i], memo)) return false;
  }
  for (size_t i = 0; i < a.people.size(); ++i) {
    if (!pair_person(a.people[i].get(), b.people[i].get(), memo)) return false;
  }
  return true;
}

}  // namespace

bool tensor_view_eq(const TensorMatrix& m, const TensorView& v) {
  return m.rows == v.rows && m.cols == v.cols && f32_payload_eq(v.values, m.values);
}

bool fidelity(const Value& a, const Value& b) {
  if (const auto* m = std::get_if<TensorMatrix>(&a)) {
    if (const auto* v = std::get_if<TensorView>(&b)) return tensor_view_eq(*m, *v);
  } else if (const auto* v = std::get_if<TensorView>(&a)) {
    if (const auto* m = std::get_if<TensorMatrix>(&b)) return tensor_view_eq(*m, *v);
  }
  if (a.index() != b.index()) return false;
  if (const auto* la = std::get_if<std::vector<double>>(&a)) {
    const auto& lb = std::get<std::vector<double>>(b);
    if (la->size() != lb.size()) return false;
    for (size_t i = 0; i < la->size(); ++i) {
      if (!nearly_eq((*la)[i], lb[i])) return false;
    }
    return true;
  }
  return std::visit(
      [&](const auto& left) -> bool {
        using T = std::decay_t<decltype(left)>;
        if constexpr (std::is_same_v<T, std::vector<double>>) {
          return false;
        } else if constexpr (std::is_same_v<T, Book>) {
          return books_equal(left, std::get<Book>(b));
        } else if constexpr (std::is_same_v<T, std::vector<Book>>) {
          const auto& right = std::get<std::vector<Book>>(b);
          if (left.size() != right.size()) return false;
          for (size_t i = 0; i < left.size(); ++i) {
            if (!books_equal(left[i], right[i])) return false;
          }
          return true;
        } else {
          return left == std::get<T>(b);
        }
      },
      a);
}

}  // namespace bench
