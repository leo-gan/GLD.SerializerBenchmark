# Build Stage
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS build

WORKDIR /app
ENV PYTHONPATH=/app/src:/app

# Copy dependency files and install
COPY python/pyproject.toml python/uv.lock ./
RUN uv sync --no-dev

# Copy generated protobuf + flatbuffers tables (schema serializers)
COPY python/generated/ ./generated/

# Copy source code, shared schemas, and Data Model v2 run configs
COPY python/src/ ./src/
COPY schemas/ ./schemas/
COPY config/library/ ./config/library/
# Master config so _repo_root() finds /app (looks for config/benchmark_config.yaml)
COPY config/benchmark_config.yaml ./config/benchmark_config.yaml
COPY schemas/data_catalog_v2.yaml ./schemas/data_catalog_v2.yaml
# analysis package for resolve_run_config / environment capture (optional import)
COPY analysis/src/benchmark_analysis/ ./analysis_src/benchmark_analysis/

# Smoke test: Data Model v2 only (type_ids message/document/telemetry/strings/event)
ENV PYTHONPATH=/app/src:/app:/app/analysis_src
RUN BENCHMARK_DATA_MODEL=v2 BENCHMARK_RUN_CONFIG=/app/config/library/smoke.yaml \
    uv run python -m benchmark.runner 1

# Final Runtime Stage
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS final

WORKDIR /app
ENV PYTHONPATH=/app/src:/app:/app/analysis_src

# Copy installed environment and source from build stage
COPY --from=build /app/ /app/

# Create volume for persistent logs
VOLUME /app/logs

# Healthcheck: ensure log file exists
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD test -f logs/python/benchmark-log.csv || exit 1

ENTRYPOINT ["uv", "run", "python", "-m", "benchmark.runner"]
CMD ["100"]
