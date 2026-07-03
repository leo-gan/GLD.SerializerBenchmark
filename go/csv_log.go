package main

import (
	"fmt"
	"os"
	"path/filepath"
)

// CsvLogger writes the monorepo CSV schema (Language=go, times in nanoseconds).
type CsvLogger struct {
	f *os.File
}

func NewCsvLogger(path string) (*CsvLogger, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return nil, err
	}
	f, err := os.Create(path)
	if err != nil {
		return nil, err
	}
	header := "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,SerializerVersion,NativeKind,StreamMode\n"
	if _, err := f.WriteString(header); err != nil {
		_ = f.Close()
		return nil, err
	}
	return &CsvLogger{f: f}, nil
}

func (c *CsvLogger) WriteRow(
	mode, testData string,
	repetitions, repIndex uint32,
	serializer string,
	timeSerNs, timeDeserNs uint64,
	size int,
	fidelity float64,
	version, nativeKind, streamMode string,
) error {
	total := timeSerNs + timeDeserNs
	opsSer, opsDeser, opsTot := 0.0, 0.0, 0.0
	if timeSerNs > 0 {
		opsSer = 1e9 / float64(timeSerNs)
	}
	if timeDeserNs > 0 {
		opsDeser = 1e9 / float64(timeDeserNs)
	}
	if total > 0 {
		opsTot = 1e9 / float64(total)
	}
	_, err := fmt.Fprintf(c.f,
		"go,%s,%s,%d,%d,%s,%d,%d,%d,%d,%.6f,%.6f,%.6f,0,%.1f,%s,%s,%s\n",
		mode, testData, repetitions, repIndex, serializer,
		timeSerNs, timeDeserNs, size, total,
		opsSer, opsDeser, opsTot, fidelity, version, nativeKind, streamMode,
	)
	return err
}

func (c *CsvLogger) Flush() error {
	return c.f.Sync()
}

func (c *CsvLogger) Close() error {
	return c.f.Close()
}
