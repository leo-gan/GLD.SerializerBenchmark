package serializers

import (
	"bytes"
	"fmt"
	"io"
	"reflect"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/bsonrw"

	"serializer-benchmark-go/model"
)

// mongoBSON — official MongoDB BSON codec (mongo-driver).
//
// Recommended (pkg.go.dev/go.mongodb.org/mongo-driver/bson):
//   - Bytes: bson.Marshal / bson.Unmarshal on structs
//   - Or Encoder/Decoder with UseJSONStructTags when structs carry `json` tags
//   - Stream: bsonrw.NewBSONValueWriter + bson.NewEncoder; Decode via
//     bsonrw.NewBSONDocumentReader + bson.NewDecoder
//   - Top-level BSON value must be a document — wrap slices as {items: [...]}
//
// Previous harness path (json.Marshal → map → bson.Marshal, and reverse) was a
// JSON envelope that inflated cost and was not the library-recommended API.
// https://www.mongodb.com/docs/drivers/go/current/fundamentals/bson/
type mongoBSON struct {
	proto   any
	wrap    bool
	payload any // prepared root (value or typed wrap with items)
}

func newMongoBSON() *mongoBSON { return &mongoBSON{} }

func (s *mongoBSON) Name() string           { return "mongo-bson" }
func (s *mongoBSON) Version() string        { return ModuleVersion("go.mongodb.org/mongo-driver") }
func (s *mongoBSON) StreamMode() StreamMode { return StreamNative }
func (s *mongoBSON) NativeKind() NativeKind { return NativeReflect }
func (s *mongoBSON) Supports(n string) bool { return DefaultSupports(n) }

func (s *mongoBSON) Prepare(fx model.Fixture) error {
	s.proto = fx.Value
	s.wrap = false
	s.payload = fx.Value
	if fx.Value == nil {
		return nil
	}
	rv := reflect.ValueOf(fx.Value)
	if rv.Kind() == reflect.Slice || rv.Kind() == reflect.Array {
		// BSON document root cannot be an array — wrap as {items: ...} (untimed).
		s.wrap = true
		st := reflect.StructOf([]reflect.StructField{{
			Name: "Items",
			Type: reflect.TypeOf(fx.Value),
			Tag:  `bson:"items" json:"items"`,
		}})
		wrap := reflect.New(st).Elem()
		wrap.Field(0).Set(rv)
		s.payload = wrap.Interface()
	}
	return nil
}

func (s *mongoBSON) SerializeBytes(_ model.Fixture) ([]byte, error) {
	// Use Encoder + UseJSONStructTags so Data Model v2 `json` tags drive field names
	// without requiring separate bson tags on every suite type.
	var buf bytes.Buffer
	if err := encodeBSON(&buf, s.payload); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func (s *mongoBSON) DeserializeBytes(data []byte) (any, error) {
	if s.wrap {
		wrap, err := newBSONItemsWrapPtr(s.proto)
		if err != nil {
			return nil, err
		}
		if err := decodeBSON(data, wrap); err != nil {
			return nil, err
		}
		return itemsFromBSONWrap(wrap), nil
	}
	dst := model.NewEmptyPtr(s.proto)
	if err := decodeBSON(data, dst); err != nil {
		return nil, err
	}
	return model.Deref(dst), nil
}

func (s *mongoBSON) SerializeStream(_ model.Fixture, w io.Writer) (int, error) {
	cw := &countWriter{w: w}
	if err := encodeBSON(cw, s.payload); err != nil {
		return 0, err
	}
	return cw.n, nil
}

func (s *mongoBSON) DeserializeStream(r io.Reader) (any, error) {
	// Read full document (BSON is length-prefixed); still uses Decoder API.
	data, err := io.ReadAll(r)
	if err != nil {
		return nil, err
	}
	return s.DeserializeBytes(data)
}

func encodeBSON(w io.Writer, v any) error {
	vw, err := bsonrw.NewBSONValueWriter(w)
	if err != nil {
		return err
	}
	enc, err := bson.NewEncoder(vw)
	if err != nil {
		return err
	}
	// Prefer `json` struct tags when `bson` tags are absent (driver-supported).
	enc.UseJSONStructTags()
	return enc.Encode(v)
}

func decodeBSON(data []byte, dst any) error {
	vr := bsonrw.NewBSONDocumentReader(data)
	dec, err := bson.NewDecoder(vr)
	if err != nil {
		return err
	}
	dec.UseJSONStructTags()
	return dec.Decode(dst)
}

func newBSONItemsWrapPtr(proto any) (any, error) {
	if proto == nil {
		return nil, fmt.Errorf("bson: nil proto")
	}
	st := reflect.StructOf([]reflect.StructField{{
		Name: "Items",
		Type: reflect.TypeOf(proto),
		Tag:  `bson:"items" json:"items"`,
	}})
	return reflect.New(st).Interface(), nil
}

func itemsFromBSONWrap(wrap any) any {
	rv := reflect.ValueOf(wrap)
	if rv.Kind() == reflect.Pointer {
		rv = rv.Elem()
	}
	return rv.FieldByName("Items").Interface()
}
