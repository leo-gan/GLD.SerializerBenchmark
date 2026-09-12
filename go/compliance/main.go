// Compliance runner — same catalog as Python / JavaScript.
//
//	go run ./compliance --json-out ../../logs/compliance/go.json
package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"runtime/debug"
	"sort"
	"strings"
	"time"

	"github.com/fxamacker/cbor/v2"
	hambaavro "github.com/hamba/avro/v2"
	goavro "github.com/linkedin/goavro/v2"
	goccyjson "github.com/goccy/go-json"
	goccyyaml "github.com/goccy/go-yaml"
	jsoniter "github.com/json-iterator/go"
	"github.com/pelletier/go-toml/v2"
	segmentiojson "github.com/segmentio/encoding/json"
	"github.com/shamaton/msgpack/v3"
	ugorji "github.com/ugorji/go/codec"
	vmsgpack "github.com/vmihailenco/msgpack/v5"
	"github.com/bytedance/sonic"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/bsonrw"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protodesc"
	"google.golang.org/protobuf/reflect/protoreflect"
	"google.golang.org/protobuf/types/descriptorpb"
	"google.golang.org/protobuf/types/dynamicpb"
)

type Case struct {
	ID             string          `json:"id"`
	Title          string          `json:"title"`
	Section        string          `json:"section"`
	SectionTitle   string          `json:"section_title"`
	SectionURL     string          `json:"section_url"`
	Paragraph      string          `json:"paragraph"`
	Requirement    string          `json:"requirement"`
	Expect         string          `json:"expect"`
	Input          string          `json:"input"`
	InputEncoding  string          `json:"input_encoding"`
	Decoded        json.RawMessage `json:"decoded"`
	HasDecoded     bool            `json:"-"`
	Schema         json.RawMessage `json:"schema"`
}

type Suite struct {
	Format      string `json:"format"`
	Standard    string `json:"standard"`
	Version     string `json:"version"`
	StandardURL string `json:"standard_url"`
	Cases       []Case `json:"cases"`
}

type Result map[string]any

type adapter struct {
	name, format, version string
	decode                func([]byte, string) (any, error)
}

func main() {
	jsonOut := flag.String("json-out", "", "write report JSON")
	var formats []string
	flag.Func("format", "limit to a format (repeatable)", func(v string) error {
		formats = append(formats, v)
		return nil
	})
	flag.Parse()
	root, err := repoRoot()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	suites, err := loadSuites(filepath.Join(root, "compliance", "data"))
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if len(formats) > 0 {
		want := map[string]bool{}
		for _, f := range formats {
			want[strings.ToLower(f)] = true
		}
		var keep []Suite
		for _, s := range suites {
			if want[strings.ToLower(s.Format)] {
				keep = append(keep, s)
			}
		}
		suites = keep
	}
	adapters := builtin()
	var adapterErrs []string
	adapters = filterByMapping(root, "go", adapters, &adapterErrs)
	byFmt := map[string][]adapter{}
	for _, a := range adapters {
		byFmt[a.format] = append(byFmt[a.format], a)
	}
	var results []Result
	for _, suite := range suites {
		chosen := byFmt[suite.Format]
		if len(chosen) == 0 {
			adapterErrs = append(adapterErrs, fmt.Sprintf("No adapter registered for format %s (%s (%s))", suite.Format, suite.Standard, suite.Version))
			continue
		}
		for _, a := range chosen {
			for _, c := range suite.Cases {
				results = append(results, runOne(suite, c, a))
			}
		}
	}
	printSummary(results, adapterErrs)
	if *jsonOut != "" {
		if err := writeReport(*jsonOut, results, adapterErrs); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Println("\nWrote", *jsonOut)
	}
}

func filterByMapping(root, language string, adapters []adapter, errs *[]string) []adapter {
	raw, err := os.ReadFile(filepath.Join(root, "compliance", "serializer-standards.json"))
	if err != nil {
		*errs = append(*errs, "missing mapping file: "+err.Error())
		return adapters
	}
	var doc struct {
		Languages map[string]map[string][]string `json:"languages"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		*errs = append(*errs, "invalid mapping file: "+err.Error())
		return adapters
	}
	allow := map[string]bool{}
	for name, fmts := range doc.Languages[language] {
		for _, fmt := range fmts {
			allow[name+"\x00"+fmt] = true
		}
	}
	var out []adapter
	for _, a := range adapters {
		if allow[a.name+"\x00"+a.format] {
			out = append(out, a)
		}
	}
	return out
}

func repoRoot() (string, error) {
	wd, _ := os.Getwd()
	dir := wd
	for i := 0; i < 8; i++ {
		if st, err := os.Stat(filepath.Join(dir, "compliance", "data")); err == nil && st.IsDir() {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "", fmt.Errorf("cannot locate compliance/data")
}

func loadSuites(root string) ([]Suite, error) {
	var suites []Suite
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".json") || strings.HasPrefix(d.Name(), "_") {
			return err
		}
		raw, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var s Suite
		if err := json.Unmarshal(raw, &s); err != nil || len(s.Cases) == 0 || s.Format == "" {
			return nil
		}
		// detect decoded presence per case
		var wrap struct {
			Cases []map[string]json.RawMessage `json:"cases"`
		}
		_ = json.Unmarshal(raw, &wrap)
		for i := range s.Cases {
			if i < len(wrap.Cases) {
				if _, ok := wrap.Cases[i]["decoded"]; ok {
					s.Cases[i].HasDecoded = true
				}
			}
		}
		suites = append(suites, s)
		return nil
	})
	if err != nil {
		return nil, err
	}
	if len(suites) == 0 {
		return nil, fmt.Errorf("no compliance suites under %s", root)
	}
	sort.Slice(suites, func(i, j int) bool {
		return suites[i].Format+suites[i].Version < suites[j].Format+suites[j].Version
	})
	return suites, nil
}

func inputBytes(c Case) ([]byte, error) {
	enc := c.InputEncoding
	if enc == "" {
		enc = "utf-8"
	}
	switch enc {
	case "hex":
		compact := strings.Map(func(r rune) rune {
			if r == ' ' || r == '\n' || r == '\t' {
				return -1
			}
			return r
		}, c.Input)
		return hex.DecodeString(compact)
	case "latin-1":
		b := make([]byte, len(c.Input))
		for i := 0; i < len(c.Input); i++ {
			b[i] = c.Input[i]
		}
		return b, nil
	default:
		return []byte(c.Input), nil
	}
}

func caseSchema(c Case) string {
	if len(c.Schema) == 0 {
		return ""
	}
	var s string
	if err := json.Unmarshal(c.Schema, &s); err == nil {
		return s
	}
	return strings.Trim(string(c.Schema), "\"")
}

func builtin() []adapter {
	jsonDec := func(fn func([]byte, any) error) func([]byte, string) (any, error) {
		return func(b []byte, _ string) (any, error) {
			var v any
			if err := fn(b, &v); err != nil {
				return nil, err
			}
			return v, nil
		}
	}
	ugorjiJSON := func(b []byte, _ string) (any, error) {
		var v any
		dec := ugorji.NewDecoderBytes(b, &ugorji.JsonHandle{})
		if err := dec.Decode(&v); err != nil {
			return nil, err
		}
		return v, nil
	}
	ugorjiCBOR := func(b []byte, _ string) (any, error) {
		var v any
		dec := ugorji.NewDecoderBytes(b, &ugorji.CborHandle{})
		if err := dec.Decode(&v); err != nil {
			return nil, err
		}
		return v, nil
	}
	ugorjiMP := func(b []byte, _ string) (any, error) {
		var v any
		dec := ugorji.NewDecoderBytes(b, &ugorji.MsgpackHandle{})
		if err := dec.Decode(&v); err != nil {
			return nil, err
		}
		return v, nil
	}
	return []adapter{
		{"encoding/json", "json", moduleVer("stdlib"), jsonDec(json.Unmarshal)},
		{"goccy/go-json", "json", moduleVer("github.com/goccy/go-json"), jsonDec(goccyjson.Unmarshal)},
		{"jsoniter", "json", moduleVer("github.com/json-iterator/go"), jsonDec(jsoniter.Unmarshal)},
		{"sonic", "json", moduleVer("github.com/bytedance/sonic"), jsonDec(sonic.Unmarshal)},
		{"segmentio/encoding/json", "json", moduleVer("github.com/segmentio/encoding"), jsonDec(segmentiojson.Unmarshal)},
		{"ugorji/json", "json", moduleVer("github.com/ugorji/go/codec"), ugorjiJSON},
		{"goccy/go-yaml", "yaml", moduleVer("github.com/goccy/go-yaml"), jsonDec(goccyyaml.Unmarshal)},
		{"pelletier/go-toml", "toml", moduleVer("github.com/pelletier/go-toml/v2"), jsonDec(toml.Unmarshal)},
		{"fxamacker/cbor", "cbor", moduleVer("github.com/fxamacker/cbor/v2"), jsonDec(cbor.Unmarshal)},
		{"ugorji/cbor", "cbor", moduleVer("github.com/ugorji/go/codec"), ugorjiCBOR},
		{"vmihailenco/msgpack", "msgpack", moduleVer("github.com/vmihailenco/msgpack/v5"), jsonDec(vmsgpack.Unmarshal)},
		{"shamaton/msgpack", "msgpack", moduleVer("github.com/shamaton/msgpack/v3"), jsonDec(msgpack.Unmarshal)},
		{"ugorji/msgpack", "msgpack", moduleVer("github.com/ugorji/go/codec"), ugorjiMP},
		{"mongo-bson", "bson", moduleVer("go.mongodb.org/mongo-driver"), func(b []byte, _ string) (any, error) {
			vr := bsonrw.NewBSONDocumentReader(b)
			dec, err := bson.NewDecoder(vr)
			if err != nil {
				return nil, err
			}
			var m bson.M
			if err := dec.Decode(&m); err != nil {
				return nil, err
			}
			return map[string]any(m), nil
		}},
		{"protobuf", "protobuf", moduleVer("google.golang.org/protobuf"), decodeProtobuf},
		{"hamba/avro", "avro", moduleVer("github.com/hamba/avro/v2"), decodeHambaAvro},
		{"linkedin/goavro", "avro", moduleVer("github.com/linkedin/goavro/v2"), decodeGoAvro},
	}
}

func avroSchemaJSON(schema string) string {
	if schema == "" {
		return `"int"`
	}
	if schema[0] == '{' || schema[0] == '[' || schema[0] == '"' {
		return schema
	}
	return `"` + schema + `"`
}

func decodeHambaAvro(b []byte, schema string) (any, error) {
	api, err := hambaavro.Parse(avroSchemaJSON(schema))
	if err != nil {
		return nil, err
	}
	var v any
	if err := hambaavro.Unmarshal(api, b, &v); err != nil {
		return nil, err
	}
	return v, nil
}

func decodeGoAvro(b []byte, schema string) (any, error) {
	codec, err := goavro.NewCodec(avroSchemaJSON(schema))
	if err != nil {
		return nil, err
	}
	native, _, err := codec.NativeFromBinary(b)
	return native, err
}

func decodeProtobuf(b []byte, schema string) (any, error) {
	msg := dynamicpb.NewMessage(pbDocDesc())
	if schema == "json" {
		opts := protojson.UnmarshalOptions{DiscardUnknown: true}
		if err := opts.Unmarshal(b, msg); err != nil {
			return nil, err
		}
	} else {
		if err := proto.Unmarshal(b, msg); err != nil {
			return nil, err
		}
	}
	return pbDocMap(msg), nil
}

func pbDocDesc() protoreflect.MessageDescriptor {
	fdp := &descriptorpb.FileDescriptorProto{
		Name:    proto.String("compliance_doc.proto"),
		Package: proto.String("cmp"),
		Syntax:  proto.String("proto3"),
		MessageType: []*descriptorpb.DescriptorProto{{
			Name: proto.String("Doc"),
			Field: []*descriptorpb.FieldDescriptorProto{
				pbField("n", 1, descriptorpb.FieldDescriptorProto_TYPE_INT32, false),
				pbField("s", 2, descriptorpb.FieldDescriptorProto_TYPE_STRING, false),
				pbField("ok", 3, descriptorpb.FieldDescriptorProto_TYPE_BOOL, false),
				pbField("tags", 4, descriptorpb.FieldDescriptorProto_TYPE_INT32, true),
			},
		}},
	}
	fd, err := protodesc.NewFile(fdp, nil)
	if err != nil {
		panic(err)
	}
	return fd.Messages().ByName("Doc")
}

func pbField(name string, num int32, typ descriptorpb.FieldDescriptorProto_Type, repeated bool) *descriptorpb.FieldDescriptorProto {
	label := descriptorpb.FieldDescriptorProto_LABEL_OPTIONAL
	if repeated {
		label = descriptorpb.FieldDescriptorProto_LABEL_REPEATED
	}
	return &descriptorpb.FieldDescriptorProto{
		Name:     proto.String(name),
		JsonName: proto.String(name),
		Number:   proto.Int32(num),
		Type:     typ.Enum(),
		Label:    label.Enum(),
	}
}

func pbDocMap(msg *dynamicpb.Message) map[string]any {
	md := msg.Descriptor()
	list := msg.Get(md.Fields().ByName("tags")).List()
	tags := make([]any, list.Len())
	for i := 0; i < list.Len(); i++ {
		tags[i] = list.Get(i).Int()
	}
	return map[string]any{
		"n":    msg.Get(md.Fields().ByName("n")).Int(),
		"s":    msg.Get(md.Fields().ByName("s")).String(),
		"ok":   msg.Get(md.Fields().ByName("ok")).Bool(),
		"tags": tags,
	}
}

func moduleVer(path string) string {
	bi, ok := debug.ReadBuildInfo()
	if !ok || bi == nil {
		return ""
	}
	if path == "stdlib" {
		return strings.TrimPrefix(bi.GoVersion, "go")
	}
	for _, d := range bi.Deps {
		if d.Path == path {
			return strings.TrimPrefix(d.Version, "v")
		}
	}
	return ""
}

func runOne(suite Suite, c Case, a adapter) Result {
	base := Result{
		"id": c.ID, "language": "go", "serializer": a.name, "serializer_version": a.version,
		"format": suite.Format, "standard": suite.Standard, "standard_url": suite.StandardURL,
		"version": suite.Version, "version_key": suite.Format + "." + suite.Version,
		"requirement": c.Requirement, "expect": c.Expect, "section": c.Section,
		"section_title": c.SectionTitle, "section_url": c.SectionURL, "paragraph": c.Paragraph,
		"title": c.Title, "input": c.Input, "input_encoding": orDefault(c.InputEncoding, "utf-8"),
		"detail": "", "observed": "", "outcome": "pass",
	}
	raw, err := inputBytes(c)
	if err != nil {
		base["outcome"] = "error"
		base["observed"] = err.Error()
		return base
	}
	got, decErr := a.decode(raw, caseSchema(c))
	if c.Expect == "any" {
		if decErr != nil {
			base["observed"] = decErr.Error()
		} else {
			base["observed"] = preview(got)
		}
		return base
	}
	if c.Expect == "reject" {
		if decErr != nil {
			base["observed"] = decErr.Error()
			return base
		}
		base["outcome"] = "fail"
		base["detail"] = "parser accepted input the spec requires to be rejected"
		base["observed"] = "accepted as " + preview(got)
		return base
	}
	if decErr != nil {
		base["outcome"] = "fail"
		base["detail"] = "parser rejected input the spec requires to accept"
		base["observed"] = decErr.Error()
		return base
	}
	if c.HasDecoded && len(c.Decoded) > 0 && string(c.Decoded) != "null" {
		var want any
		if err := json.Unmarshal(c.Decoded, &want); err == nil && !valuesEqual(want, got) {
			base["outcome"] = "fail"
			base["detail"] = "decoded value does not match the catalog case"
			base["observed"] = "got " + preview(got) + ", want " + preview(want)
			return base
		}
	}
	base["observed"] = preview(got)
	return base
}

func orDefault(s, d string) string {
	if s == "" {
		return d
	}
	return s
}

func valuesEqual(expected, observed any) bool {
	if m, ok := expected.(map[string]any); ok && len(m) == 1 {
		if hx, ok := m["$hex"]; ok {
			b, ok := asBytes(observed)
			if !ok {
				return false
			}
			want, err := hex.DecodeString(strings.ReplaceAll(fmt.Sprint(hx), " ", ""))
			return err == nil && bytes.Equal(b, want)
		}
	}
	if expected == nil {
		return observed == nil
	}
	switch e := expected.(type) {
	case bool:
		o, ok := observed.(bool)
		return ok && e == o
	case float64:
		switch o := observed.(type) {
		case float64:
			if math.IsNaN(e) {
				return math.IsNaN(o)
			}
			return e == o
		case int:
			return e == float64(o)
		case int64:
			return e == float64(o)
		case uint64:
			return e == float64(o)
		}
	case string:
		if b, ok := asBytes(observed); ok {
			return string(b) == e
		}
		o, ok := observed.(string)
		return ok && e == o
	case []any:
		o, ok := observed.([]any)
		if !ok || len(e) != len(o) {
			return false
		}
		for i := range e {
			if !valuesEqual(e[i], o[i]) {
				return false
			}
		}
		return true
	case map[string]any:
		o, ok := observed.(map[string]any)
		if !ok || len(e) != len(o) {
			return false
		}
		for k, ev := range e {
			if !valuesEqual(ev, o[k]) {
				return false
			}
		}
		return true
	}
	return fmt.Sprint(expected) == fmt.Sprint(observed)
}

func asBytes(v any) ([]byte, bool) {
	switch t := v.(type) {
	case []byte:
		return t, true
	case primitive.Binary:
		return t.Data, true
	}
	return nil, false
}

func preview(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		s := fmt.Sprint(v)
		if len(s) > 120 {
			return s[:117] + "..."
		}
		return s
	}
	if len(b) > 120 {
		return string(b[:117]) + "..."
	}
	return string(b)
}

func printSummary(results []Result, adapterErrs []string) {
	var p, f, s, e int
	by := map[string][3]int{}
	for _, r := range results {
		switch r["outcome"] {
		case "pass":
			p++
		case "fail":
			f++
		case "skip":
			s++
		default:
			e++
		}
		key := fmt.Sprintf("%s (%s) × %s", r["standard"], r["version"], r["serializer"])
		c := by[key]
		switch r["outcome"] {
		case "pass":
			c[0]++
		case "fail":
			c[1]++
		default:
			c[2]++
		}
		by[key] = c
	}
	fmt.Println("Serialization compliance (library deviations are catalogued, not a red build)")
	fmt.Printf("  %d pass  %d fail  %d skip  %d error  %d total\n", p, f, s, e, len(results))
	if len(adapterErrs) > 0 {
		fmt.Println("  Adapter errors:")
		for _, a := range adapterErrs {
			fmt.Println("    -", a)
		}
	}
	fmt.Println("  By suite × adapter:")
	keys := make([]string, 0, len(by))
	for k := range by {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		c := by[k]
		fmt.Printf("    %s: %d pass, %d fail, %d skip\n", k, c[0], c[1], c[2])
	}
}

func writeReport(path string, results []Result, adapterErrs []string) error {
	var p, f, s, e int
	fmts := map[string]bool{}
	for _, r := range results {
		switch r["outcome"] {
		case "pass":
			p++
		case "fail":
			f++
		case "skip":
			s++
		default:
			e++
		}
		if x, ok := r["format"].(string); ok {
			fmts[x] = true
		}
	}
	formatList := make([]string, 0, len(fmts))
	for k := range fmts {
		formatList = append(formatList, k)
	}
	sort.Strings(formatList)
	doc := map[string]any{
		"schema": "gld.dashboard.compliance/1",
		"generated_at": time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		"language": "go", "languages": []string{"go"}, "policy": "report-only",
		"scope": map[string]any{"formats": formatList},
		"passed": p, "failed": f, "skipped": s, "errors": e,
		"catalog_errors": []string{}, "serializer_errors": adapterErrs,
		"results": results,
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	raw, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(raw, '\n'), 0o644)
}
