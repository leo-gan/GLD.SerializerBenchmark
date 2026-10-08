package serializers

import (
	"bytes"
	"testing"
	"time"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
)

func v2Cell(id string, n int) model.Fixture {
	name, val := modelv2.FixtureFromCell(modelv2.Cell{TypeID: id, DataTypeInstanceCount: n}, 42)
	return model.Fixture{Name: name, Value: val}
}

func domainOut(ser BenchSerializer, out any) (any, error) {
	if conv, ok := ser.(DomainConverter); ok {
		return conv.ToDomain(out)
	}
	return out, nil
}

func checkRoundTrip(t *testing.T, ser BenchSerializer, fx model.Fixture) {
	t.Helper()
	if err := ser.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	buf, err := ser.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	if len(buf) == 0 {
		t.Fatal("empty payload")
	}
	out, err := ser.DeserializeBytes(buf)
	if err != nil {
		t.Fatal(err)
	}
	out, err = domainOut(ser, out)
	if err != nil {
		t.Fatal(err)
	}
	expected := fx.Value
	if fx.Name == "table_project" {
		expected = modelv2.ProjectFFloat0(fx.Value)
		got, ok := out.([]float64)
		if !ok {
			t.Fatalf("table_project got %T", out)
		}
		n := 1
		if rows, ok := fx.Value.([]modelv2.TableRow); ok {
			n = len(rows)
		}
		if len(got) != n {
			t.Fatalf("table_project len %d want %d", len(got), n)
		}
	}
	if !model.Fidelity(expected, out) {
		t.Fatalf("fidelity failed: got %#v", out)
	}
	var stream bytes.Buffer
	n, err := ser.SerializeStream(fx, &stream)
	if err != nil {
		t.Fatalf("stream ser: %v", err)
	}
	if n == 0 || stream.Len() == 0 {
		t.Fatal("empty stream")
	}
	out2, err := ser.DeserializeStream(bytes.NewReader(stream.Bytes()))
	if err != nil {
		t.Fatalf("stream deser: %v", err)
	}
	out2, err = domainOut(ser, out2)
	if err != nil {
		t.Fatal(err)
	}
	if !model.Fidelity(expected, out2) {
		t.Fatalf("stream fidelity failed")
	}
}

func TestColumnarRoundTrip(t *testing.T) {
	names := []string{
		"arrow-ipc", "parquet", "parquet-uncompressed", "sbe",
		"encoding/json", "protobuf", "hamba/avro",
	}
	byName := map[string]BenchSerializer{}
	for _, ser := range All() {
		byName[ser.Name()] = ser
	}
	ids := []string{"table", "table_project", "nested_table", "signal"}
	for _, n := range []int{1, 100} {
		for _, id := range ids {
			fx := v2Cell(id, n)
			for _, name := range names {
				ser := byName[name]
				if !ser.Supports(id) {
					if name == "sbe" && id == "nested_table" {
						continue
					}
					t.Fatalf("%s should support %s", name, id)
				}
				t.Run(name+"/"+id, func(t *testing.T) {
					checkRoundTrip(t, ser, fx)
				})
			}
		}
	}
}

func TestParquetCompressionDiffers(t *testing.T) {
	fx := v2Cell("table", 100)
	snappy := newParquet()
	raw := newParquetUncompressed()
	if err := snappy.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	if err := raw.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	a, err := snappy.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	b, err := raw.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(a, b) {
		t.Fatalf("snappy and uncompressed parquet match (%d bytes)", len(a))
	}
}

func TestIPCProjectionMatchesColumn0(t *testing.T) {
	fx := v2Cell("table", 100)
	ser := newArrowIPC()
	if err := ser.Prepare(fx); err != nil {
		t.Fatal(err)
	}
	buf, err := ser.SerializeBytes(fx)
	if err != nil {
		t.Fatal(err)
	}
	full, err := ser.DeserializeBytes(buf)
	if err != nil {
		t.Fatal(err)
	}
	want := modelv2.ProjectFFloat0(full)
	if err := ser.Prepare(model.Fixture{Name: "table_project", Value: fx.Value}); err != nil {
		t.Fatal(err)
	}
	got, err := ser.DeserializeBytes(buf)
	if err != nil {
		t.Fatal(err)
	}
	if !model.Fidelity(want, got) {
		t.Fatalf("ipc projection != column 0")
	}
}

func TestColumnarProjectionDeserTime(t *testing.T) {
	const n = 10000
	const reps = 5
	for _, name := range []string{"arrow-ipc", "parquet"} {
		var ser BenchSerializer
		for _, s := range All() {
			if s.Name() == name {
				ser = s
			}
		}
		fx := v2Cell("table", n)
		if err := ser.Prepare(fx); err != nil {
			t.Fatal(err)
		}
		buf, err := ser.SerializeBytes(fx)
		if err != nil {
			t.Fatal(err)
		}
		if _, err := ser.DeserializeBytes(buf); err != nil {
			t.Fatal(err)
		}
		t0 := time.Now()
		for i := 0; i < reps; i++ {
			if _, err := ser.DeserializeBytes(buf); err != nil {
				t.Fatal(err)
			}
		}
		full := time.Since(t0)
		projFx := model.Fixture{Name: "table_project", Value: fx.Value}
		if err := ser.Prepare(projFx); err != nil {
			t.Fatal(err)
		}
		if _, err := ser.DeserializeBytes(buf); err != nil {
			t.Fatal(err)
		}
		t1 := time.Now()
		for i := 0; i < reps; i++ {
			if _, err := ser.DeserializeBytes(buf); err != nil {
				t.Fatal(err)
			}
		}
		proj := time.Since(t1)
		t.Logf("%s N=%d reps=%d deser full=%s proj=%s (%.2fx)", name, n, reps, full, proj, float64(full)/float64(proj))
		if proj*2 >= full {
			t.Fatalf("%s projection deser %s is not clearly faster than full %s", name, proj, full)
		}
	}
}
