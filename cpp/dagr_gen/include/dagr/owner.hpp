// dagr/owner.hpp — owner identity and liveness for the multi-producer SharedBuffer
// strategies (spec/40 §3.2, §4.3; spec/41 §11): a lock word or a ring slot records WHICH
// process holds it, and a waiter takes it over only once that process is gone — never on a
// timeout, which would let a merely paused holder resume and write beside the new one.
//
// The owner word is BIT-IDENTICAL across languages (processes of different languages share
// one lock): pid in the low 32 bits, the process's start token in the high 32 — a port of
// targets/go/dagr/owner.go. Linux and macOS (POSIX); the start token comes from
// /proc/<pid>/stat where it exists (Linux) and is 0 elsewhere, as in every target.
//
// Not core tier: it talks to the operating system (getpid, kill, /proc).
#pragma once

#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstring>

#include <sched.h>
#include <signal.h>
#include <unistd.h>

namespace dagr {

namespace detail {

/// The low 32 bits of a process's start time (Linux: /proc/<pid>/stat field 22, clock
/// ticks since boot), or-ed with 1 so that it is never 0; 0 where it is not available —
/// liveness then goes by pid alone, and a reused pid can delay a recovery but never cause
/// a wrong one.
inline std::uint32_t start_token(long pid) noexcept {
  char path[64];
  std::snprintf(path, sizeof path, "/proc/%ld/stat", pid);
  std::FILE* f = std::fopen(path, "r");
  if (f == nullptr) return 0;
  char buf[1024];
  const std::size_t n = std::fread(buf, 1, sizeof buf - 1, f);
  std::fclose(f);
  buf[n] = '\0';
  const char* close = std::strrchr(buf, ')');   // the command name may contain spaces
  if (close == nullptr) return 0;
  // fields 3.. follow ") "; field 22 (starttime) is the 20th of them
  const char* q = close + 1;
  for (int field = 0; field < 19; field++) {
    while (*q == ' ') q++;
    while (*q != ' ' && *q != '\0') q++;
    if (*q == '\0') return 0;
  }
  while (*q == ' ') q++;
  std::uint64_t v = 0;
  bool any = false;
  for (; *q >= '0' && *q <= '9'; q++) {
    v = v * 10 + static_cast<std::uint64_t>(*q - '0');
    any = true;
  }
  if (!any) return 0;
  return static_cast<std::uint32_t>(v) | 1u;
}

}  // namespace detail

/// This process's identity: pid in the low 32 bits, its start token in the high 32. Never
/// zero (zero is "unowned"). Computed once.
inline std::uint64_t owner_self() noexcept {
  static const std::uint64_t self = [] {
    const long pid = static_cast<long>(::getpid());
    return static_cast<std::uint64_t>(static_cast<std::uint32_t>(pid)) |
           (static_cast<std::uint64_t>(detail::start_token(pid)) << 32);
  }();
  return self;
}

/// Whether the process an owner word names still exists. A process always counts itself
/// alive (its threads cannot die without it), and any doubt answers "alive": a false
/// "dead" would let two writers run at once, a false "alive" only delays recovery.
inline bool owner_alive(std::uint64_t owner) noexcept {
  const long pid = static_cast<long>(static_cast<std::uint32_t>(owner));
  if (owner == 0 || pid == static_cast<long>(::getpid())) return true;
  if (::kill(static_cast<pid_t>(pid), 0) != 0 && errno == ESRCH) return false;
  // the pid exists — the same process, or a later one that reused the pid?
  const std::uint32_t token = static_cast<std::uint32_t>(owner >> 32);
  if (token != 0) {
    const std::uint32_t current = detail::start_token(pid);
    if (current != 0 && current != token) return false;
  }
  return true;
}

/// Gives the processor to another thread — what a spinning waiter does now and then.
inline void owner_yield() noexcept { ::sched_yield(); }

}  // namespace dagr
