// Serializer benchmark runner for Go (Python/Rust-aligned prepare/timed call path).
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"serializer-benchmark-go/model"
	"serializer-benchmark-go/serializers"
)

func defaultLogDir() string {
	if d := os.Getenv("LOG_DIR"); d != "" {
		if strings.HasSuffix(filepath.Clean(d), "go") {
			return d
		}
		return filepath.Join(d, "go")
	}
	cwd, _ := os.Getwd()
	for dir := cwd; dir != "/" && dir != "."; dir = filepath.Dir(dir) {
		if _, err := os.Stat(filepath.Join(dir, "config", "benchmark_config.yaml")); err == nil {
			return filepath.Join(dir, "logs", "go")
		}
	}
	return filepath.Join(cwd, "logs", "go")
}

func measureBytes(ser serializers.BenchSerializer, fx model.Fixture) (serNs, deserNs uint64, size int, err error) {
	t0 := time.Now()
	buf, err := ser.SerializeBytes(fx)
	serNs = uint64(time.Since(t0).Nanoseconds())
	if err != nil {
		return
	}
	size = len(buf)

	t1 := time.Now()
	out, err := ser.DeserializeBytes(buf)
	deserNs = uint64(time.Since(t1).Nanoseconds())
	if err != nil {
		return
	}
	if !model.Fidelity(fx.Value, out) {
		err = fmt.Errorf("roundtrip fidelity failed for %s", ser.Name())
	}
	return
}

func measureStream(ser serializers.BenchSerializer, fx model.Fixture) (serNs, deserNs uint64, size int, err error) {
	buf := &bytes.Buffer{}
	buf.Grow(4096)

	t0 := time.Now()
	n, err := ser.SerializeStream(fx, buf)
	serNs = uint64(time.Since(t0).Nanoseconds())
	if err != nil {
		return
	}
	size = n

	r := bytes.NewReader(buf.Bytes())
	t1 := time.Now()
	out, err := ser.DeserializeStream(r)
	deserNs = uint64(time.Since(t1).Nanoseconds())
	if err != nil {
		return
	}
	if !model.Fidelity(fx.Value, out) {
		err = fmt.Errorf("stream roundtrip fidelity failed for %s", ser.Name())
	}
	return
}

func main() {
	repsFlag := flag.Uint("reps", 10, "repetitions per serializer+data+mode")
	serFilter := flag.String("serializer", "", "substring filter for serializer names")
	dataFilter := flag.String("data", "", "substring filter for test data names")
	logDirFlag := flag.String("log-dir", "", "output log directory")
	flag.Parse()

	repetitions := uint32(*repsFlag)
	sf, df := *serFilter, *dataFilter
	if flag.NArg() >= 1 {
		var r uint64
		if _, err := fmt.Sscanf(flag.Arg(0), "%d", &r); err == nil && r > 0 {
			repetitions = uint32(r)
		}
	}
	if flag.NArg() >= 2 && sf == "" {
		sf = flag.Arg(1)
	}
	if flag.NArg() >= 3 && df == "" {
		df = flag.Arg(2)
	}

	logDir := *logDirFlag
	if logDir == "" {
		logDir = defaultLogDir()
	}
	if err := os.MkdirAll(logDir, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "mkdir log dir: %v\n", err)
		os.Exit(1)
	}

	ts := os.Getenv("BENCHMARK_TS")
	if ts == "" {
		ts = time.Now().Format("2006-01-02-150405")
	}
	logPath := filepath.Join(logDir, ts+".csv")
	logger, err := NewCsvLogger(logPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "csv: %v\n", err)
		os.Exit(1)
	}
	defer logger.Close()

	fmt.Fprintf(os.Stderr, "[PROGRESS] Writing results under %s\n", logDir)

	var sers []serializers.BenchSerializer
	for _, s := range serializers.All() {
		if sf != "" && !strings.Contains(strings.ToLower(s.Name()), strings.ToLower(sf)) {
			continue
		}
		sers = append(sers, s)
	}

	var fxs []model.Fixture
	for _, fx := range model.AllFixtures(42) {
		if df != "" && !strings.Contains(strings.ToLower(fx.Name), strings.ToLower(df)) {
			continue
		}
		fxs = append(fxs, fx)
	}

	modes := []string{"bytes", "stream"}
	fmt.Printf("[PROGRESS] Go benchmark: %d serializers, %d data types, %d reps\n", len(sers), len(fxs), repetitions)

	for _, fx := range fxs {
		fmt.Printf("[PROGRESS] Testing Data: %s\n", fx.Name)
		for _, ser := range sers {
			if !ser.Supports(fx.Name) {
				continue
			}
			if err := ser.Prepare(fx); err != nil {
				fmt.Fprintf(os.Stderr, "[ERROR] prepare %s / %s: %v\n", ser.Name(), fx.Name, err)
				continue
			}
			for _, mode := range modes {
				hadError := false
				for i := uint32(0); i < repetitions; i++ {
					var serNs, deserNs uint64
					var size int
					var merr error
					if mode == "bytes" {
						serNs, deserNs, size, merr = measureBytes(ser, fx)
					} else {
						serNs, deserNs, size, merr = measureStream(ser, fx)
					}
					if merr != nil {
						if !hadError {
							fmt.Fprintf(os.Stderr, "[ERROR] %s / %s / %s: %v\n", ser.Name(), fx.Name, mode, merr)
							hadError = true
						}
						continue
					}
					if hadError {
						continue
					}
					_ = logger.WriteRow(
						mode, fx.Name, repetitions, i, ser.Name(),
						serNs, deserNs, size, 1.0,
						ser.Version(), ser.NativeKind().String(), ser.StreamMode().String(),
					)
				}
			}
		}
	}

	_ = logger.Flush()
	fmt.Printf("[PROGRESS] Complete. Results: %s\n", logPath)
}
