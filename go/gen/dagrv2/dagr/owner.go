//go:build unix

package dagr

// Owner identity and liveness for the multi-producer SharedBuffer strategies (spec/40
// §3.2, §4.3): a lock word or a ring slot records WHICH process holds it, and a waiter
// takes it over only once that process is gone — never on a timeout, which would let a
// merely paused holder resume and write beside the new one.

import (
	"errors"
	"os"
	"strconv"
	"strings"
	"sync"
	"syscall"
)

var (
	ownerOnce sync.Once
	ownerSelf uint64
)

// OwnerSelf is this process's identity: pid in the low 32 bits, its start token in the
// high 32. Never zero (zero is "unowned").
func OwnerSelf() uint64 {
	ownerOnce.Do(func() {
		pid := os.Getpid()
		ownerSelf = uint64(uint32(pid)) | uint64(startToken(pid))<<32
	})
	return ownerSelf
}

// OwnerAlive reports whether the process an owner word names still exists. A process
// always counts itself alive (its threads cannot die without it), and any doubt answers
// "alive": a false "dead" would let two writers run at once, a false "alive" only
// delays recovery.
func OwnerAlive(owner uint64) bool {
	pid := int(uint32(owner))
	if owner == 0 || pid == os.Getpid() {
		return true
	}
	if err := syscall.Kill(pid, 0); err != nil && errors.Is(err, syscall.ESRCH) {
		return false
	}
	// the pid exists — the same process, or a later one that reused the pid?
	if tok := uint32(owner >> 32); tok != 0 {
		if cur := startToken(pid); cur != 0 && cur != tok {
			return false
		}
	}
	return true
}

// startToken is the low 32 bits of a process's start time where the platform exposes it
// cheaply (Linux: /proc/<pid>/stat field 22, in clock ticks since boot), else 0 — then
// liveness goes by pid alone, and a reused pid can delay a recovery but never cause a
// wrong one.
func startToken(pid int) uint32 {
	b, err := os.ReadFile("/proc/" + strconv.Itoa(pid) + "/stat")
	if err != nil {
		return 0
	}
	s := string(b)
	i := strings.LastIndexByte(s, ')') // the command name may contain spaces
	if i < 0 {
		return 0
	}
	f := strings.Fields(s[i+1:]) // fields 3.. of stat
	if len(f) < 20 {
		return 0
	}
	v, err := strconv.ParseUint(f[19], 10, 64) // field 22: starttime
	if err != nil {
		return 0
	}
	return uint32(v) | 1 // never 0, which means "unknown"
}
