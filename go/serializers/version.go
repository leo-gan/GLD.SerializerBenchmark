package serializers

import (
	"runtime/debug"
	"strings"
)

// ModuleVersion returns the version of a Go module as embedded in the binary
// build info (e.g. "v1.15.2" → "1.15.2"). Empty if unknown.
func ModuleVersion(modulePath string) string {
	bi, ok := debug.ReadBuildInfo()
	if !ok || bi == nil {
		return ""
	}
	for _, d := range bi.Deps {
		if d.Path == modulePath {
			return strings.TrimPrefix(d.Version, "v")
		}
	}
	// Main module / stdlib markers. GoVersion is already like "go1.24.13".
	if modulePath == "stdlib" {
		return bi.GoVersion
	}
	return ""
}
