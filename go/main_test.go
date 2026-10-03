package main

import (
	"strings"
	"testing"

	"serializer-benchmark-go/serializers"
)

func TestSerializerFilterAllowList(t *testing.T) {
	allow := "arrow-ipc,parquet,parquet-uncompressed,sbe,encoding/json,protobuf,hamba/avro"
	var got []string
	for _, s := range serializers.All() {
		if serializerSelected(s.Name(), allow) {
			got = append(got, s.Name())
		}
	}
	t.Logf("allow-list selects: %s", strings.Join(got, ","))
	want := []string{
		"encoding/json", "protobuf", "hamba/avro",
		"arrow-ipc", "parquet", "parquet-uncompressed", "sbe",
	}
	if strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("selected %v", got)
	}
	for _, excluded := range []string{"linkedin/goavro", "sonic", "encoding/json/v2", "segmentio/encoding/json", "goccy/go-json"} {
		if serializerSelected(excluded, allow) {
			t.Fatalf("allow-list selected %s", excluded)
		}
	}
	if !serializerSelected("encoding/json/v2", "encoding/json") {
		t.Fatal("substring filter should match encoding/json/v2")
	}
	if !serializerSelected("segmentio/encoding/json", "encoding/json") {
		t.Fatal("substring filter should match segmentio/encoding/json")
	}
	if !serializerSelected("anything", "") {
		t.Fatal("empty filter selects all")
	}
	if !serializerSelected("Parquet", "arrow-ipc,PARQUET") {
		t.Fatal("exact match is case-insensitive")
	}
}
