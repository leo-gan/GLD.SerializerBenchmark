package v2

import (
	"encoding/json"
	"reflect"
	"strings"
	"testing"
)

func TestColumnarDeterministic(t *testing.T) {
	for _, id := range []string{"table", "table_project", "nested_table", "signal"} {
		a := MakeOne(id, nil, 42, 3)
		b := MakeOne(id, nil, 42, 3)
		if !reflect.DeepEqual(a, b) {
			t.Fatalf("%s not deterministic", id)
		}
		c := MakeOne(id, nil, 42, 4)
		if reflect.DeepEqual(a, c) {
			t.Fatalf("%s instance index did not change values", id)
		}
	}
	if reflect.DeepEqual(MakeOne("table", nil, 7, 0), MakeOne("table_project", nil, 7, 0)) {
		t.Fatal("table and table_project must differ because mixSeed includes type id")
	}
}

func TestTableStringDuplication(t *testing.T) {
	const n = 40
	vocab := sharedVocab(99, "table", 3, 16)
	set := map[string]struct{}{}
	for _, w := range vocab {
		set[w] = struct{}{}
	}
	rows := make([]TableRow, n)
	for i := 0; i < n; i++ {
		rows[i] = MakeOne("table", nil, 99, i).(TableRow)
	}
	again := make([]TableRow, n)
	for i := 0; i < n; i++ {
		again[i] = MakeOne("table", nil, 99, i).(TableRow)
	}
	if !reflect.DeepEqual(rows, again) {
		t.Fatal("40-row table not deterministic")
	}
	inVocab := 0
	for _, row := range rows {
		if _, ok := set[row.FStr0]; ok {
			inVocab++
		}
		if _, ok := set[row.FStr1]; ok {
			inVocab++
		}
	}
	// duplication default 0.5 over 80 strings. Fresh words rarely collide with the vocab.
	if inVocab < 24 || inVocab > 56 {
		t.Fatalf("vocab hits %d/80, want about half at duplication 0.5", inVocab)
	}
	fresh := 80 - inVocab
	if fresh == 0 {
		t.Fatal("expected some fresh strings at duplication 0.5")
	}

	low := map[string]any{"duplication": 0.0}
	lowHits := 0
	for i := 0; i < n; i++ {
		row := MakeOne("table", low, 99, i).(TableRow)
		if _, ok := set[row.FStr0]; ok {
			lowHits++
		}
		if _, ok := set[row.FStr1]; ok {
			lowHits++
		}
	}
	if lowHits > 4 {
		t.Fatalf("duplication 0 still hit vocab %d times", lowHits)
	}
}

func TestSignalFieldOrderAndLegPad(t *testing.T) {
	sig := MakeOne("signal", nil, 42, 0).(Signal)
	want := []string{"Seq", "TS", "PriceMantissa", "Qty", "Flags", "Symbol", "Venue", "Legs"}
	rt := reflect.TypeOf(sig)
	if rt.NumField() != len(want) {
		t.Fatalf("field count %d", rt.NumField())
	}
	for i, name := range want {
		if rt.Field(i).Name != name {
			t.Fatalf("field %d = %s, want %s", i, rt.Field(i).Name, name)
		}
	}
	if len(sig.Legs) != 4 {
		t.Fatalf("legs %d", len(sig.Legs))
	}
	for i, leg := range sig.Legs {
		if leg.LegPad != 0 {
			t.Fatalf("leg %d pad %d", i, leg.LegPad)
		}
		if leg.LegID < 0 || leg.LegID > 1_000_000 || leg.LegQty < 0 || leg.LegQty > 10_000 {
			t.Fatalf("leg %d out of range: %+v", i, leg)
		}
	}
	if sig.Seq < 0 || sig.Seq > 1_000_000_000 || sig.Flags < 0 || sig.Flags > 65535 {
		t.Fatalf("signal out of range: %+v", sig)
	}
	if sig.TS < baseTSMS || sig.TS > baseTSMS+86_400_000 {
		t.Fatalf("ts %d", sig.TS)
	}
	raw, err := json.Marshal(sig)
	if err != nil {
		t.Fatal(err)
	}
	text := string(raw)
	symbol := strings.Index(text, `"symbol"`)
	venue := strings.Index(text, `"venue"`)
	legs := strings.Index(text, `"legs"`)
	if symbol < 0 || venue < 0 || legs < 0 || !(symbol < venue && venue < legs) {
		t.Fatalf("domain order want symbol, venue, then legs: %s", text)
	}
	short := MakeOne("signal", map[string]any{"group_count": float64(2)}, 1, 0).(Signal)
	if len(short.Legs) != 2 {
		t.Fatalf("group_count override: %d", len(short.Legs))
	}
}

func TestNestedTableDefaults(t *testing.T) {
	row := MakeOne("nested_table", nil, 5, 1).(NestedRow)
	if len(row.Items) != 4 {
		t.Fatalf("children default %d", len(row.Items))
	}
	if row.ID == "" || row.Meta.Region == "" {
		t.Fatalf("%+v", row)
	}
	if row.Status < 0 || row.Status > 5 || row.Meta.Version < 1 || row.Meta.Version > 10 {
		t.Fatalf("out of range %+v", row)
	}
	for _, it := range row.Items {
		if it.Qty < 1 || it.Qty > 100 || it.PriceMinor < 0 || it.PriceMinor > 100000 {
			t.Fatalf("item %+v", it)
		}
	}
}

func TestFixtureBatchTypes(t *testing.T) {
	for _, id := range []string{"table", "table_project", "nested_table", "signal"} {
		name, val := FixtureFromCell(Cell{TypeID: id, DataTypeInstanceCount: 3}, 9)
		if name != id {
			t.Fatal(name)
		}
		if reflect.TypeOf(val).Kind() != reflect.Slice {
			t.Fatalf("%s N=3: %T", id, val)
		}
		_, one := FixtureFromCell(Cell{TypeID: id, DataTypeInstanceCount: 1}, 9)
		if reflect.TypeOf(one).Kind() == reflect.Slice {
			t.Fatalf("%s N=1 should be one value, got %T", id, one)
		}
	}
	_, batch := FixtureFromCell(Cell{TypeID: "table", DataTypeInstanceCount: 2}, 1)
	if _, ok := batch.([]TableRow); !ok {
		t.Fatalf("%T", batch)
	}
	_, nest := FixtureFromCell(Cell{TypeID: "nested_table", DataTypeInstanceCount: 2}, 1)
	if _, ok := nest.([]NestedRow); !ok {
		t.Fatalf("%T", nest)
	}
	_, sig := FixtureFromCell(Cell{TypeID: "signal", DataTypeInstanceCount: 2}, 1)
	if _, ok := sig.([]Signal); !ok {
		t.Fatalf("%T", sig)
	}
	proj := ProjectFFloat0(batch)
	if len(proj) != 2 {
		t.Fatalf("project %d", len(proj))
	}
	one := ProjectFFloat0(MakeOne("table_project", nil, 3, 0))
	if len(one) != 1 {
		t.Fatalf("N=1 project %d", len(one))
	}
}
