#!/usr/bin/env bash
# scripts/dev-docs.sh: Run integrated local docs + dashboard watch server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cleanup background processes on Ctrl+C
cleanup() {
  echo -e "\nStopping watch servers..."
  kill 0
}
trap cleanup EXIT

echo "Performing initial dashboard build..."
cd "$PROJECT_ROOT/dashboard"
npm run build

echo "Starting Vite incremental build watch..."
npx vite build --watch &

echo "Starting MkDocs local server..."
cd "$PROJECT_ROOT"
mkdocs serve &

# Keep script running and wait for background processes
wait
