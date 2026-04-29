# Build Stage
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS build

WORKDIR /app
ENV PYTHONPATH=/app/src:/app

# Copy dependency files and install
COPY python/pyproject.toml python/uv.lock ./
RUN uv sync --no-dev

# Copy generated protobuf files (needed for protobuf serializer)
COPY python/generated/ ./generated/

# Copy source code and shared schemas
COPY python/src/ ./src/
COPY schemas/ ./schemas/

# Smoke test: verify the benchmark can run 1 rep of pickle on Person
RUN uv run python -m benchmark.runner 1 pickle Person

# Final Runtime Stage
FROM ghcr.io/astral-sh/uv:python3.12-bookworm AS final

WORKDIR /app
ENV PYTHONPATH=/app/src:/app

# Copy installed environment and source from build stage
COPY --from=build /app/ /app/

# Create volume for persistent logs
VOLUME /app/logs

# Healthcheck: ensure log file exists
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD test -f logs/python/benchmark-log.csv || exit 1

ENTRYPOINT ["uv", "run", "python", "-m", "benchmark.runner"]
CMD ["100"]
