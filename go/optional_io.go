package main

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

func findOptionalIoFile() string {
	cwd, err := os.Getwd()
	if err != nil {
		return ""
	}
	for dir := cwd; dir != "/" && dir != "."; dir = filepath.Dir(dir) {
		p := filepath.Join(dir, "config", "optional-io.txt")
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

func optionalStreamNames(language string) map[string]bool {
	out := map[string]bool{}
	path := findOptionalIoFile()
	if path == "" {
		return out
	}
	f, err := os.Open(path)
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		lang, name, ok := strings.Cut(sc.Text(), "\t")
		if ok && lang == language && name != "" {
			out[name] = true
		}
	}
	return out
}

func modesWithOptionalStream(modes []string, opt map[string]bool, present []string) []string {
	hit := false
	for _, name := range present {
		if opt[name] {
			hit = true
			break
		}
	}
	if !hit {
		return modes
	}
	for _, mode := range modes {
		if mode == "stream" {
			return modes
		}
	}
	next := append([]string{}, modes...)
	return append(next, "stream")
}
