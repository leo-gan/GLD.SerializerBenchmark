#!/usr/bin/env bash
# Soft checks for research-oriented L2/L3 collection.
# Warns only — never fails CI smoke by default.
#
# Usage:
#   BENCHMARK_RESEARCH=1 ./scripts/check-research-env.sh
#   ./scripts/check-research-env.sh   # still runs, but quieter about intent
set -euo pipefail

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'
WARN=0

ok()   { echo -e "  ${GREEN}OK${NC}  $*"; }
warn() { echo -e "  ${YELLOW}WARN${NC} $*"; WARN=$((WARN + 1)); }

echo "Research-host soft checks (non-fatal)"
if [[ "${BENCHMARK_RESEARCH:-}" == "1" ]]; then
  echo "  BENCHMARK_RESEARCH=1 — treating this as a publication-oriented host"
else
  echo "  (set BENCHMARK_RESEARCH=1 to emphasize research-mode guidance)"
fi

# CPU governor (Linux)
gov_path="/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
if [[ -r "$gov_path" ]]; then
  gov="$(tr -d '[:space:]' <"$gov_path" || true)"
  if [[ "$gov" == "performance" ]]; then
    ok "cpu governor=$gov"
  elif [[ -n "$gov" ]]; then
    warn "cpu governor=$gov (prefer 'performance' for stable L2/L3 timings)"
  else
    warn "cpu governor unreadable content"
  fi
else
  warn "cpu governor not available (non-Linux or no cpufreq sysfs)"
fi

# Load average vs cores (very rough quiet-host hint)
if command -v nproc >/dev/null 2>&1 && [[ -r /proc/loadavg ]]; then
  cores="$(nproc)"
  load1="$(awk '{print $1}' /proc/loadavg)"
  # bash arithmetic only on integers — use awk for float compare
  busy="$(awk -v l="$load1" -v c="$cores" 'BEGIN { print (l > c*0.75) ? 1 : 0 }')"
  if [[ "$busy" == "1" ]]; then
    warn "loadavg 1m=$load1 on ${cores} cores (host may be busy)"
  else
    ok "loadavg 1m=$load1 on ${cores} cores"
  fi
fi

# isolcpus is optional and rare on developer laptops
if [[ -r /proc/cmdline ]] && grep -q 'isolcpus=' /proc/cmdline 2>/dev/null; then
  ok "isolcpus present in kernel cmdline"
else
  echo "  note: isolcpus not set (optional; not required for ordinary L1 Results)"
fi

echo
if [[ "$WARN" -gt 0 ]]; then
  echo "Finished with $WARN warning(s). See docs/analysis/CLAIMS_AND_REPLICATION.md"
else
  echo "Finished with no warnings."
fi
# Always exit 0 — soft check only
exit 0
