# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src

# Copy solution and project files
COPY GLD.SerializerBenchmark.sln .
COPY GLD.SerializerBenchmark/GLD.SerializerBenchmark.csproj GLD.SerializerBenchmark/

# Restore dependencies
RUN dotnet restore

# Copy all source code (including pre-generated Bond types)
COPY . .

# Build the application
RUN dotnet build GLD.SerializerBenchmark/GLD.SerializerBenchmark.csproj -c Release -o /app/build

# Build-time verification (Smoke Test)
# This fails the build if the application cannot run or basic serialization fails.
RUN dotnet run --project GLD.SerializerBenchmark/GLD.SerializerBenchmark.csproj -c Release -- 1 Binary Person

# Publish Stage
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS publish
WORKDIR /src
COPY --from=build /src .
RUN dotnet publish GLD.SerializerBenchmark/GLD.SerializerBenchmark.csproj -c Release -o /app/publish /p:UseAppHost=false

# Final Runtime Stage
FROM mcr.microsoft.com/dotnet/runtime:6.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Create a volume for persistent logs
VOLUME /app/logs

# Healthcheck: Verify that the log file exists and is being updated (activity check)
# Since the app might not be running constantly, we check for file existence as a baseline.
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD test -f logs/SerializerBenchmark_Log.csv || exit 1

ENTRYPOINT ["dotnet", "GLD.SerializerBenchmark.dll"]
CMD ["100"]
