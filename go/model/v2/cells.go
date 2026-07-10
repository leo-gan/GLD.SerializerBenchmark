package v2

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// Cell is one expanded workload from resolve_run_config.
type Cell struct {
	TypeID                 string         `json:"type_id"`
	TypeConfig             map[string]any `json:"type_config"`
	TypeConfigHash         string         `json:"type_config_hash"`
	DataTypeInstanceCount  int            `json:"data_type_instance_count"`
}

// ResolvedRun is the resolver JSON document.
type ResolvedRun struct {
	Cells []Cell `json:"cells"`
	Seed  *int   `json:"seed"`
	RunConfig struct {
		Path          string `json:"path"`
		ContentSHA256 string `json:"content_sha256"`
		ID            string `json:"id"`
	} `json:"run_config"`
	Execution struct {
		IOModes []string `json:"io_modes"`
	} `json:"execution"`
}

func repoRoot() string {
	cwd, _ := os.Getwd()
	for dir := cwd; dir != "/" && dir != "."; dir = filepath.Dir(dir) {
		if _, err := os.Stat(filepath.Join(dir, "config", "benchmark_config.yaml")); err == nil {
			return dir
		}
	}
	return cwd
}

// LoadResolved runs scripts/resolve_run_config.py and parses cells.
func LoadResolved(runConfigPath string, seed uint64) (*ResolvedRun, error) {
	root := repoRoot()
	script := filepath.Join(root, "scripts", "resolve_run_config.py")
	if runConfigPath == "" {
		runConfigPath = filepath.Join(root, "config", "library", "default.yaml")
	}
	if !filepath.IsAbs(runConfigPath) {
		// Prefer monorepo-relative path over process cwd (avoids ../config escapes).
		candidate := filepath.Join(root, strings.TrimPrefix(runConfigPath, "./"))
		if _, err := os.Stat(candidate); err == nil {
			runConfigPath = candidate
		} else {
			runConfigPath = filepath.Join(root, runConfigPath)
		}
	}
	cmd := exec.Command("python3", script, runConfigPath, "--seed", strconv.FormatUint(seed, 10))
	cmd.Dir = root
	// PYTHONPATH for analysis package
	cmd.Env = append(os.Environ(), "PYTHONPATH="+filepath.Join(root, "analysis", "src"))
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return nil, fmt.Errorf("resolve_run_config: %v: %s", err, string(ee.Stderr))
		}
		return nil, err
	}
	var rr ResolvedRun
	if err := json.Unmarshal(out, &rr); err != nil {
		return nil, err
	}
	return &rr, nil
}

// FixtureFromCell builds suite fixture value (single instance or []any batch).
func FixtureFromCell(c Cell, seed uint64) (name string, value any) {
	n := c.DataTypeInstanceCount
	if n < 1 {
		n = 1
	}
	insts := Instances(c.TypeID, c.TypeConfig, seed, n)
	name = c.TypeID
	if n == 1 {
		return name, insts[0]
	}
	// Concrete typed slices for JSON codecs that need typed empty ptr
	switch c.TypeID {
	case "message":
		s := make([]Message, n)
		for i := range insts {
			s[i] = insts[i].(Message)
		}
		return name, s
	case "document":
		s := make([]Document, n)
		for i := range insts {
			s[i] = insts[i].(Document)
		}
		return name, s
	case "telemetry":
		s := make([]Telemetry, n)
		for i := range insts {
			s[i] = insts[i].(Telemetry)
		}
		return name, s
	case "strings":
		s := make([]Strings, n)
		for i := range insts {
			s[i] = insts[i].(Strings)
		}
		return name, s
	case "event":
		s := make([]Event, n)
		for i := range insts {
			s[i] = insts[i].(Event)
		}
		return name, s
	default:
		return name, insts
	}
}

// IsV2TypeName reports whether name is a Data Model v2 type_id.
func IsV2TypeName(name string) bool {
	switch name {
	case "message", "document", "telemetry", "strings", "event":
		return true
	default:
		return false
	}
}
