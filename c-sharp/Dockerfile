# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy solution and project files
COPY GLD.SerializerBenchmark.sln .
COPY src/GLD.SerializerBenchmark.csproj src/

# Restore dependencies
RUN dotnet restore

# Copy all source code (including pre-generated Bond types)
COPY . .

# Build the application
RUN dotnet build src/GLD.SerializerBenchmark.csproj -c Release -o /app/build

# Build-time verification (Smoke Test)
# This fails the build if the application cannot run or basic serialization fails.
# Include SharpSerializer: net8 needs custom IInstanceCreator (see Serializers/SharpSerializer.cs).
RUN dotnet run --project src/GLD.SerializerBenchmark.csproj -c Release -- 1 Binary message \
 && dotnet run --project src/GLD.SerializerBenchmark.csproj -c Release -- 1 SharpSerializer message \
 && dotnet run --project src/GLD.SerializerBenchmark.csproj -c Release -- 1 SharpSerializer telemetry

# Publish Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS publish
WORKDIR /src
COPY --from=build /src .
RUN dotnet publish src/GLD.SerializerBenchmark.csproj -c Release -o /app/publish /p:UseAppHost=false

# Final Runtime Stage
FROM mcr.microsoft.com/dotnet/runtime:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .

# Create a volume for persistent logs
VOLUME /app/logs

# Healthcheck: Verify that the log file exists and is being updated (activity check)
# Since the app might not be running constantly, we check for file existence as a baseline.
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD ls logs/csharp/*.csv 1>/dev/null 2>&1 || exit 1

ENTRYPOINT ["dotnet", "GLD.SerializerBenchmark.dll"]
CMD ["100"]
# rebuild 1783652345
# force 1783652460644059000
# 1783652592
# 1783652696
# 1783652979
# 1783653167
# 1783653471
# 1783653634
# 1783653821
# rebuild 1783654766
