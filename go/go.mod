module serializer-benchmark-go

// Direct requires are minimum versions (Go MVS). Patch/minor bumps within the
// same module major path (e.g. hamba/avro/v2) are safe to take via:
//   go get -u=patch ./... && go get <module>@latest && go mod tidy
// Avoid jumping to a new major import path (e.g. mongo-driver/v2) without a harness review.

go 1.24.0

toolchain go1.24.13

require (
	github.com/bytedance/sonic v1.15.2
	github.com/fxamacker/cbor/v2 v2.9.2
	github.com/goccy/go-json v0.10.6
	github.com/goccy/go-yaml v1.19.2
	github.com/hamba/avro/v2 v2.31.0
	github.com/json-iterator/go v1.1.12
	github.com/kelindar/binary v1.0.19
	github.com/pelletier/go-toml/v2 v2.4.3
	github.com/segmentio/encoding v0.5.4
	github.com/shamaton/msgpack/v3 v3.1.2
	github.com/ugorji/go/codec v1.3.1
	github.com/vmihailenco/msgpack/v5 v5.4.1
	go.mongodb.org/mongo-driver v1.17.9
	google.golang.org/protobuf v1.36.11
)

require (
	github.com/bytedance/gopkg v0.1.4 // indirect
	github.com/bytedance/sonic/loader v0.5.1 // indirect
	github.com/cloudwego/base64x v0.1.7 // indirect
	github.com/go-viper/mapstructure/v2 v2.4.0 // indirect
	github.com/klauspost/cpuid/v2 v2.2.11 // indirect
	github.com/modern-go/concurrent v0.0.0-20180306012644-bacd9c7ef1dd // indirect
	github.com/modern-go/reflect2 v1.0.2 // indirect
	github.com/segmentio/asm v1.1.5 // indirect
	github.com/twitchyliquid64/golang-asm v0.15.1 // indirect
	github.com/vmihailenco/tagparser/v2 v2.0.0 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	golang.org/x/arch v0.0.0-20210923205945-b76863e36670 // indirect
	golang.org/x/sys v0.30.0 // indirect
)
