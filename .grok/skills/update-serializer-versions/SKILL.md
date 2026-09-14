---
name: update-serializer-versions
description: >
  Check every language tree (including git-vendored Mojo/Swift/Zig, not only
  package registries) for newer same-line serializer releases, bump pins,
  re-bench, and re-run compliance for those languages. Use when the user
  runs /update-serializer-versions, says "update serializer versions",
  "bump library versions", "check upstream releases", or "update serializer
  information".
metadata:
  short-description: "Bump same-line serializer pins, re-bench, re-run compliance"
---

# /update-serializer-versions

Resolve repo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
```

A version bump is not done after the lockfile changes. For every language whose
installed serializer version changed: **re-bench and re-run compliance**.
Dashboard `npm test` is not a substitute for either.

---

## 1. Check every language

Do **not** skip a language because it has no PyPI/npm/crates/Maven/NuGet/Go
module. Query the pin’s actual upstream.

| Lang | Pin lives in | Query |
|------|----------------|-------|
| python | `python/pyproject.toml` + `python/uv.lock` | PyPI |
| javascript | `javascript/package.json` + `package-lock.json` | npm |
| go | `go/go.mod` + `go.sum` | proxy.golang.org |
| rust | `rust/Cargo.toml` + `Cargo.lock` | crates.io |
| java | `java/pom.xml` + `java/src/main/resources/benchmark-versions.properties` | Maven Central |
| kotlin | `kotlin/build.gradle.kts` | Maven Central |
| csharp | `c-sharp/src/*.csproj` | NuGet |
| php | `php/composer.json` + lock | Packagist |
| c | `c/third_party/VERSIONS.md` + `c/scripts/fetch-and-build-deps.sh` | GitHub/GitLab tags |
| cpp | `cpp/CMakeLists.txt` + `cpp/third_party/VERSIONS.md` | GitHub tags / FetchContent |
| swift | `swift/Package.swift` (`from:` / `exact:`) + `Package.resolved` | GitHub tags |
| zig | `zig/build.zig.zon` + versions in `zig/src/serializers.zig` | GitHub/Codeberg tags |
| mojo | `mojo/scripts/fetch-vendors.sh` (`--branch` / clone URL) + `mojo/vendor/**` | GitHub tags |

Same-line only:

- Bump newer **same major** (and same `0.x` minor line).
- Skip a new **major**, or a `0.x` jump that changes the minor (e.g. `0.0.4` → `0.2.0`), unless the user asked for breaking upgrades.
- Skip if the new release needs a newer host toolchain than this repo documents (record the skip).
- Floating pins (`13.*`, `^7.2`) are **not** “already current.” Query NuGet/Packagist (or `dotnet list package --outdated` / Packagist) against the **resolved** version in `project.assets.json` / `composer.lock`. Restore/update if the registry has a newer same-line release.
- Missing `php` / `dotnet` / `composer` is not “unchanged.” Run `./scripts/install-host-requirements.sh <lang>` and query again.

Write a bump table: lang | serializer | was | now | skipped (reason).

---

## 2. Apply pins and rebuild

For each bump: edit the pin, refresh the lock, rebuild so the runner actually
loads the new bits (stale jars, FetchContent dirs, and `third_party/_prefix`
will silently keep the old library).

| Lang | After the pin edit |
|------|--------------------|
| python | `cd python && uv lock --upgrade-package <pkg> && uv sync` |
| javascript | `cd javascript && npm install` |
| go | `cd go && go get <mod>@<ver> && go mod tidy` |
| rust | `cd rust && cargo update -p <crate>` |
| java | edit `pom.xml` **and** `benchmark-versions.properties`; `mvn -q -DskipTests clean package` |
| kotlin | `./gradlew clean shadowJar` (or the suite’s usual fat-jar target) |
| csharp | `dotnet restore` |
| php | `composer update <pkg>` |
| c | update `VERSIONS.md` + fetch script; wipe the relevant `third_party/_prefix` / `_build` artifact, then `c/scripts/fetch-and-build-deps.sh` |
| cpp | wipe the matching `_fetch/<name>-*` and `cpp/build` if FetchContent is stale; reconfigure |
| swift | `cd swift && swift package update` (confirm `Package.resolved`) |
| zig | new tag URL + hash in `build.zig.zon`; keep `serializers.zig` version strings in sync |
| mojo | point `fetch-vendors.sh` at the new tag; run it; do not leave sibling-checkout copies at the old tree |

If docs/`VERSIONS.md` list the version, update those in the same change. Specifics versions come from the catalog regen in step 3.

---

## 3. Re-bench every bumped language

```bash
for lang in $BUMPED_LANGS; do
  ./scripts/run-all-benchmarks.sh --mode full --lang "$lang" --analyze
done
python3 dashboard/scripts/sync-data.py
```

Hard fail if a language run exits non-zero. Confirm CSV `SerializerVersion`
matches the new pin.

Refresh the source catalog so `config/serializer-sources.json` `version`
fields match the new benches:

```bash
python3 dashboard/scripts/write-serializer-sources.py
python3 scripts/apply-serializer-sources-to-docs.py
```

---

## 4. Re-run compliance for those languages (**required**)

```bash
args=()
for lang in $BUMPED_LANGS; do
  args+=(--lang "$lang")
done
./scripts/run-compliance.sh "${args[@]}"
```

- Writes `logs/compliance/latest-<lang>.json`. The script then runs
  `dashboard/scripts/sync-compliance.py` → `dashboard/public/data/compliance.json.gz`.
- Library misses are report-only. Exit `2` = catalog load failure (hard fail).
- Hard fail if a bumped language that has a compliance runner is missing
  `logs/compliance/latest-<lang>.json` after the run.
- Long-running: background + monitor.

Do **not** stop after benches, analysis, or dashboard unit tests.

---

## 5. Report

| Lang | Bumps | Bench stem | Compliance pass/fail | Notes |

Unchanged languages stay off the bench and compliance command lines.

## Stop conditions

| Condition | Action |
|-----------|--------|
| A language was never queried (registry *or* git tags) | Do not mark it unchanged; query it |
| Pin edited but runner still reports the old `SerializerVersion` | Rebuild; wipe stale prefix/FetchContent/jars |
| Bench fails | Stop; do not skip compliance “to finish later” |
| Compliance runner fails or `latest-<lang>.json` missing | Stop |
