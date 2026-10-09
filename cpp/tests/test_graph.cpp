#include "bench/fixture.hpp"
#include "bench/serializer.hpp"

#include <iostream>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace {

int g_fail = 0;

void expect(bool cond, const std::string& msg) {
  if (!cond) {
    std::cerr << "FAIL " << msg << "\n";
    ++g_fail;
  }
}

bench::ISerializer* find_ser(std::vector<bench::SerializerPtr>& sers, const std::string& name) {
  for (auto& ser : sers) {
    if (ser && ser->name() == name) return ser.get();
  }
  return nullptr;
}

void check_identity(const bench::Book& book, int orders, int regions, int ring, int smin, int smax,
                    const std::string& label) {
  expect(static_cast<int>(book.orders.size()) == orders, label + " order count");
  expect(static_cast<int>(book.people.size()) == ring, label + " ring size");
  std::map<const bench::Region*, int> counts;
  for (const bench::Order& order : book.orders) {
    expect(order.region != nullptr, label + " null region");
    expect(order.qty >= 1 && order.qty <= 100, label + " qty");
    expect(order.sku.size() >= static_cast<size_t>(smin) && order.sku.size() <= static_cast<size_t>(smax),
           label + " sku length");
    if (order.region == nullptr) continue;
    expect(order.region->note.size() == 64, label + " note length");
    expect(order.region->version >= 1 && order.region->version <= 10, label + " version");
    expect(order.region->code.size() >= static_cast<size_t>(smin) &&
               order.region->code.size() <= static_cast<size_t>(smax),
           label + " code length");
    counts[order.region]++;
  }
  expect(static_cast<int>(counts.size()) == regions, label + " distinct regions");
  if (regions > 0 && orders % regions == 0) {
    for (const auto& entry : counts) {
      expect(entry.second == orders / regions, label + " orders per region");
    }
  }
  if (ring <= 0) return;
  const bench::Person* node = book.people[0].get();
  for (int i = 0; i < ring; ++i) {
    expect(node != nullptr, label + " ring walked off");
    if (node == nullptr) return;
    node = node->next;
  }
  expect(node == book.people[0].get(), label + " ring closes");
  for (int i = 0; i < ring; ++i) {
    expect(book.people[static_cast<size_t>(i)]->next ==
               book.people[static_cast<size_t>((i + 1) % ring)].get(),
           label + " people[i].next");
  }
}

bench::Book duplicate_regions(const bench::Book& book) {
  bench::Book dup;
  dup.orders.reserve(book.orders.size());
  for (const bench::Order& order : book.orders) {
    auto region = std::make_unique<bench::Region>(*order.region);
    bench::Order copy;
    copy.sku = order.sku;
    copy.qty = order.qty;
    copy.region = region.get();
    dup.regions.push_back(std::move(region));
    dup.orders.push_back(std::move(copy));
  }
  dup.people.reserve(book.people.size());
  for (const auto& person : book.people) {
    auto node = std::make_unique<bench::Person>();
    node->name = person->name;
    dup.people.push_back(std::move(node));
  }
  for (size_t i = 0; i < dup.people.size(); ++i) {
    dup.people[i]->next = dup.people[(i + 1) % dup.people.size()].get();
  }
  return dup;
}

void check_decoded(const bench::Book& got, const bench::Book& expected, const std::string& label) {
  expect(bench::fidelity(bench::Value{expected}, bench::Value{got}), label + " fidelity");
  check_identity(got, static_cast<int>(expected.orders.size()), static_cast<int>(expected.regions.size()),
                 static_cast<int>(expected.people.size()), 8, 16, label);
}

void roundtrip(bench::ISerializer& ser, const bench::Fixture& fx) {
  const std::string label = std::string(ser.name()) + " N=" + std::to_string(fx.instance_count);
  ser.prepare(fx);
  const auto buf = ser.serialize_bytes(fx);
  expect(!buf.empty(), label + " empty");
  const bench::Value out = ser.to_domain(ser.deserialize_bytes(buf));
  expect(bench::fidelity(bench::expected_for_fidelity(fx), out), label + " fidelity");
  if (fx.instance_count <= 1) {
    check_decoded(std::get<bench::Book>(out), std::get<bench::Book>(fx.value), label);
    return;
  }
  const auto& got = std::get<std::vector<bench::Book>>(out);
  const auto& expected = std::get<std::vector<bench::Book>>(fx.value);
  expect(got.size() == expected.size(), label + " batch size");
  std::set<const void*> seen;
  for (size_t i = 0; i < got.size() && i < expected.size(); ++i) {
    const std::string item = label + " [" + std::to_string(i) + "]";
    check_decoded(got[i], expected[i], item);
    std::set<const void*> local;
    for (const bench::Order& order : got[i].orders) local.insert(order.region);
    for (const auto& person : got[i].people) local.insert(person.get());
    for (const void* node : local) {
      expect(seen.insert(node).second, item + " node shared with another graph");
    }
  }
}

}  // namespace

int run_graph_checks() {
  using namespace bench;
  TypeConfig cfg;
  auto fx = make_fixture("graph", cfg, 42, 1, "g");
  const Book& book = std::get<Book>(fx.value);
  check_identity(book, 32, 4, 8, 8, 16, "generator");
  expect(book.regions.size() == 4, "generator owns 4 regions");

  auto again = make_fixture("graph", cfg, 42, 1, "g");
  expect(fidelity(fx.value, again.value), "same seed matches");
  auto second = make_fixture("graph", cfg, 99, 1, "g");
  expect(!fidelity(fx.value, second.value), "different seed differs");

  Book copy = book;
  expect(fidelity(Value{book}, Value{copy}), "deep copy keeps identity");
  expect(copy.orders[0].region != book.orders[0].region, "deep copy owns new regions");
  expect(copy.orders[0].region == copy.orders[4].region, "deep copy still shares a region");
  expect(copy.people[0]->next == copy.people[1].get(), "deep copy ring");
  expect(copy.people[0].get() != book.people[0].get(), "deep copy owns new people");

  Book duplicated = duplicate_regions(book);
  expect(!fidelity(Value{book}, Value{duplicated}), "duplicated region fails");
  Book collapsed = book;
  for (size_t i = 0; i < collapsed.people.size(); ++i) {
    collapsed.people[i]->next = collapsed.people[0].get();
  }
  expect(!fidelity(Value{book}, Value{collapsed}), "unrolled ring fails");
  Book tweaked = book;
  tweaked.orders[0].region->code.push_back('z');
  expect(!fidelity(Value{book}, Value{tweaked}), "field mismatch fails");

  auto batch = make_fixture("graph", cfg, 42, 2, "g");
  const auto& books = std::get<std::vector<Book>>(batch.value);
  expect(books.size() == 2, "N=2 is two graphs");
  expect(!fidelity(Value{books[0]}, Value{books[1]}), "N>1 instances differ");
  expect(books[0].orders[0].region != books[1].orders[0].region, "N>1 regions are independent");
  expect(books[0].people[0].get() != books[1].people[0].get(), "N>1 people are independent");

  TypeConfig small;
  small.order_count = 4;
  small.region_count = 2;
  small.ring_size = 3;
  small.string_len_min = 8;
  small.string_len_max = 8;
  auto small_fx = make_fixture("graph", small, 5, 1, "g");
  check_identity(std::get<Book>(small_fx.value), 4, 2, 3, 8, 8, "custom");
  expect(std::get<Book>(small_fx.value).orders[0].region->note.size() == 64, "custom note is 64");

  auto all = all_serializers();
  for (const auto& ser : all) {
    if (!ser) continue;
    const bool want = std::string(ser->name()) == "dagr-regular" || std::string(ser->name()) == "dagr-frozen";
    expect(ser->supports("graph") == want, std::string(ser->name()) + " supports(graph)");
    if (std::string(ser->name()).rfind("dagr-", 0) == 0) {
      expect(ser->supports("message"), std::string(ser->name()) + " supports(message)");
      expect(!ser->supports("table"), std::string(ser->name()) + " skips columnar");
    }
  }

  for (const char* name : {"dagr-regular", "dagr-frozen"}) {
    auto* ser = find_ser(all, name);
    expect(ser != nullptr, std::string("missing ") + name);
    if (ser == nullptr) continue;
    for (const Fixture& cell : {fx, batch, small_fx}) {
      try {
        roundtrip(*ser, cell);
      } catch (const std::exception& e) {
        expect(false, std::string(name) + " N=" + std::to_string(cell.instance_count) + ": " + e.what());
      }
    }
  }

  if (g_fail == 0) std::cout << "OK graph checks\n";
  return g_fail == 0 ? 0 : 1;
}
