#!/usr/bin/env bash
# Pack Gld.Kiln from git tag 0.2.0 into the local NuGet feed the csproj restores.
# Not a ProjectReference to a local checkout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FEED="$CS_DIR/src/obj/gld-kiln-feed"
TAG="0.2.0"
REPO="https://github.com/leo-gan/gld-kiln-csharp"

mkdir -p "$FEED"
if compgen -G "$FEED/*.nupkg" > /dev/null; then
  exit 0
fi

SRC="$CS_DIR/src/obj/gld-kiln-src"
rm -rf "$SRC"
GIT_TERMINAL_PROMPT=0 git clone --depth 1 --branch "$TAG" "$REPO" "$SRC"
got="$(git -C "$SRC" describe --exact-match --tags)"
if [[ "$got" != "$TAG" ]]; then
  echo "[ERROR] gld-kiln-csharp tag is '$got', expected $TAG" >&2
  exit 1
fi

export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
dotnet pack "$SRC/src/Kiln/Kiln.csproj" -c Release -o "$FEED" --nologo -v q
rm -rf "$SRC"

if ! compgen -G "$FEED/*.nupkg" > /dev/null; then
  echo "[ERROR] Gld.Kiln $TAG pack produced no nupkg in $FEED" >&2
  exit 1
fi
echo "[INFO] Packed Gld.Kiln $TAG from $REPO into $FEED"
