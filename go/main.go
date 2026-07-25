// Serializer benchmark runner for Go (Python/Rust-aligned prepare/timed call path).
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"serializer-benchmark-go/model"
	modelv2 "serializer-benchmark-go/model/v2"
	"serializer-benchmark-go/serializers"
)

type benchError struct {
	testDataName   string
	serializerName string
	stringOrStream string
	repetition     uint32
	errorText      string
}

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

// saveErrors writes per-run error CSV, or removes any prior file when clean
// (same policy as python report.save_errors).
func saveErrors(path string, errors []benchError) error {
	if len(errors) == 0 {
		_ = os.Remove(path)
		return nil
	}
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	// Schema matches C# / Python (not JS Language column).
	if _, err := f.WriteString("TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n"); err != nil {
		return err
	}
	for _, e := range errors {
		text := strings.ReplaceAll(e.errorText, "\n", " ")
		text = strings.ReplaceAll(text, ",", ";")
		if _, err := fmt.Fprintf(f, "%s,%s,%s,%d,%s\n",
			e.testDataName, e.serializerName, e.stringOrStream, e.repetition, text); err != nil {
			return err
		}
	}
	return nil
}

// toDomain runs optional untimed library-native → suite-domain conversion
// (e.g. protobuf Message → modelv2.Message) after the timed deserialize path.
func toDomain(ser serializers.BenchSerializer, out any) (any, error) {
	if conv, ok := ser.(serializers.DomainConverter); ok {
		return conv.ToDomain(out)
	}
	return out, nil
}

func measureBytes(ser serializers.BenchSerializer, fx model.Fixture) (serNs, deserNs uint64, size int, err error) {
	t0 := time.Now()
	buf, err := ser.SerializeBytes(fx)
	serNs = uint64(time.Since(t0).Nanoseconds())
	if err != nil {
		return
	}
	// KeepAlive: prevent compiler from DCE'ing timed work (issue #59).
	runtime.KeepAlive(buf)
	size = len(buf)

	t1 := time.Now()
	out, err := ser.DeserializeBytes(buf)
	deserNs = uint64(time.Since(t1).Nanoseconds())
	if err != nil {
		return
	}
	runtime.KeepAlive(out)
	// Domain conversion is intentionally outside the timer (fair codec measurement).
	out, err = toDomain(ser, out)
	if err != nil {
		return
	}
	if !model.Fidelity(fx.Value, out) {
		err = fmt.Errorf("roundtrip fidelity failed for %s", ser.Name())
	}
	return
}

// measureStream reuses streamBuf across reps (caller owns it; issue #59 buffer policy).
func measureStream(ser serializers.BenchSerializer, fx model.Fixture, streamBuf *bytes.Buffer) (serNs, deserNs uint64, size int, err error) {
	streamBuf.Reset()

	t0 := time.Now()
	n, err := ser.SerializeStream(fx, streamBuf)
	serNs = uint64(time.Since(t0).Nanoseconds())
	if err != nil {
		return
	}
	runtime.KeepAlive(streamBuf)
	size = n

	r := bytes.NewReader(streamBuf.Bytes())
	t1 := time.Now()
	out, err := ser.DeserializeStream(r)
	deserNs = uint64(time.Since(t1).Nanoseconds())
	if err != nil {
		return
	}
	runtime.KeepAlive(out)
	out, err = toDomain(ser, out)
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
		if r, err := strconv.ParseUint(flag.Arg(0), 10, 32); err == nil && r > 0 {
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

	// Same stem as other harnesses: BENCHMARK_TS or YYYY-MM-DD-HHMMSS (never custom ad-hoc names).
	ts := os.Getenv("BENCHMARK_TS")
	if ts == "" {
		ts = time.Now().Format("2006-01-02-150405")
		// Export so capture_environment / child tools see the same stem (Rust does this too).
		_ = os.Setenv("BENCHMARK_TS", ts)
	}
	logPath := filepath.Join(logDir, ts+".csv")
	errPath := filepath.Join(logDir, ts+".errors.csv")
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

	// Seed from config/benchmark_config.yaml via BENCHMARK_SEED (run scripts set it).
	seed := uint64(42)
	if s := os.Getenv("BENCHMARK_SEED"); s != "" {
		if parsed, err := strconv.ParseUint(s, 10, 64); err == nil {
			seed = parsed
		}
	}

	// Suite type ids: message, document, telemetry, strings, event.
	modes := []string{"bytes", "stream"}

	type workItem struct {
		fx             model.Fixture
		instanceCount  int
		typeConfigHash string
	}
	var work []workItem

	runCfg := os.Getenv("BENCHMARK_RUN_CONFIG")
	resolved, err := modelv2.LoadResolved(runCfg, seed)
	if err != nil {
		fmt.Fprintf(os.Stderr, "v2 resolve: %v\n", err)
		os.Exit(1)
	}
	if len(resolved.Execution.IOModes) > 0 {
		modes = resolved.Execution.IOModes
	}
	for _, c := range resolved.Cells {
		if df != "" && !strings.Contains(strings.ToLower(c.TypeID), strings.ToLower(df)) {
			continue
		}
		name, val := modelv2.FixtureFromCell(c, seed)
		work = append(work, workItem{
			fx:             model.Fixture{Name: name, Value: val},
			instanceCount:  c.DataTypeInstanceCount,
			typeConfigHash: c.TypeConfigHash,
		})
	}
	strategy := resolveScheduleStrategy()
	recordRO := resolveRecordRunOrder()
	fmt.Printf("[PROGRESS] Go Data Model v2: %d serializers, %d cells, %d reps, modes=%v schedule=%s\n",
		len(sers), len(work), repetitions, modes, strategy)

	var errors []benchError
	runOrder := 0

	for _, w := range work {
		fx := w.fx
		fmt.Printf("[PROGRESS] Testing Data: %s (N=%d)\n", fx.Name, w.instanceCount)

		// Untimed prepare once per cell; per-serializer stream buffers (B-1).
		type prepared struct {
			ser       serializers.BenchSerializer
			streamBuf *bytes.Buffer
		}
		var ready []prepared
		failed := map[string]bool{}
		for _, ser := range sers {
			if !ser.Supports(fx.Name) {
				continue
			}
			if err := ser.Prepare(fx); err != nil {
				fmt.Fprintf(os.Stderr, "[ERROR] prepare %s / %s: %v\n", ser.Name(), fx.Name, err)
				errors = append(errors, benchError{
					testDataName:   fx.Name,
					serializerName: ser.Name(),
					stringOrStream: "prepare",
					repetition:     0,
					errorText:      err.Error(),
				})
				failed[ser.Name()] = true
				continue
			}
			ready = append(ready, prepared{
				ser:       ser,
				streamBuf: bytes.NewBuffer(make([]byte, 0, 64*1024)),
			})
		}
		byName := map[string]prepared{}
		for _, p := range ready {
			byName[p.ser.Name()] = p
		}

		// Log every successful rep including i==0 (warmup). Analysis drops warmup later.
		for _, mode := range modes {
			for i := uint32(0); i < repetitions; i++ {
				var order []prepared
				if strategy == "none" {
					order = ready
				} else {
					var names []string
					for _, p := range ready {
						if failed[p.ser.Name()] {
							continue
						}
						names = append(names, p.ser.Name())
					}
					shuffled := fisherYatesStrings(names, deriveScheduleSeed(
						seed, fx.Name, w.instanceCount, w.typeConfigHash, mode, i))
					for _, nm := range shuffled {
						order = append(order, byName[nm])
					}
				}
				for pos, p := range order {
					if failed[p.ser.Name()] {
						continue
					}
					ser := p.ser
					var serNs, deserNs uint64
					var size int
					var merr error
					if mode == "bytes" {
						serNs, deserNs, size, merr = measureBytes(ser, fx)
					} else {
						serNs, deserNs, size, merr = measureStream(ser, fx, p.streamBuf)
					}
					if merr != nil {
						fmt.Fprintf(os.Stderr, "[ERROR] %s / %s / %s: %v\n", ser.Name(), fx.Name, mode, merr)
						errors = append(errors, benchError{
							testDataName:   fx.Name,
							serializerName: ser.Name(),
							stringOrStream: mode,
							repetition:     i,
							errorText:      merr.Error(),
						})
						failed[ser.Name()] = true
						continue
					}
					ro, sp := -1, -1
					if recordRO {
						ro, sp = runOrder, pos
						runOrder++
					}
					_ = logger.WriteRow(
						mode, fx.Name, repetitions, i, ser.Name(),
						serNs, deserNs, size, 1.0,
						ser.Version(), ser.NativeKind().String(), ser.StreamMode().String(),
						w.instanceCount, w.typeConfigHash,
						ro, sp,
					)
				}
			}
		}
	}

	_ = logger.Flush()
	if err := saveErrors(errPath, errors); err != nil {
		fmt.Fprintf(os.Stderr, "[WARN] could not write errors csv: %v\n", err)
	}
	fmt.Printf("[PROGRESS] Complete. Results: %s\n", logPath)
}
