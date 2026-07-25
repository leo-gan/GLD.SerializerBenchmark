package main

import (
	"crypto/sha256"
	"encoding/binary"
	"os"
	"strconv"
	"strings"
)

// B-1 block_shuffle schedule (golden: A,B,C → C,B,A at seed 42 / message / 1 / abc / bytes / 0).

func normalizeMode(mode string) string {
	m := strings.ToLower(strings.TrimSpace(mode))
	switch m {
	case "string", "buffer":
		return "bytes"
	case "stream":
		return "stream"
	default:
		return m
	}
}

func deriveScheduleSeed(baseSeed uint64, typeID string, instanceCount int, typeConfigHash, mode string, rep uint32) uint64 {
	key := strconv.FormatUint(baseSeed, 10) + "|" + typeID + "|" +
		strconv.Itoa(instanceCount) + "|" + typeConfigHash + "|" +
		normalizeMode(mode) + "|" + strconv.FormatUint(uint64(rep), 10)
	sum := sha256.Sum256([]byte(key))
	return binary.LittleEndian.Uint64(sum[:8])
}

type splitMix64 struct{ state uint64 }

func (r *splitMix64) nextU64() uint64 {
	r.state += 0x9E3779B97F4A7C15
	z := r.state
	z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27)) * 0x94D049BB133111EB
	return z ^ (z >> 31)
}

func fisherYatesStrings(names []string, seed uint64) []string {
	arr := append([]string(nil), names...)
	rng := splitMix64{state: seed}
	for i := len(arr) - 1; i > 0; i-- {
		j := int(rng.nextU64() % uint64(i+1))
		arr[i], arr[j] = arr[j], arr[i]
	}
	return arr
}

func resolveScheduleStrategy() string {
	env := strings.ToLower(strings.TrimSpace(os.Getenv("BENCHMARK_SCHEDULE")))
	if env == "none" || env == "block_shuffle" {
		return env
	}
	return "block_shuffle"
}

func resolveRecordRunOrder() bool {
	env := strings.ToLower(strings.TrimSpace(os.Getenv("BENCHMARK_RECORD_RUN_ORDER")))
	if env == "0" || env == "false" || env == "no" {
		return false
	}
	return true
}
