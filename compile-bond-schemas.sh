#!/bin/bash
# Compile Bond schema files to C# classes
# Requires Bond compiler (gbc) to be installed:
#   dotnet tool install --global Bond.Compiler

set -e

BOND_DIR="GLD.SerializerBenchmark/Bond"
NAMESPACE="GLD.SerializerBenchmark.Bond"

echo "Compiling Bond schemas..."

# Compile each .bond file
for schema in "$BOND_DIR"/*.bond; do
    if [ -f "$schema" ]; then
        echo "  Compiling: $schema"
        gbc --csharpcodegen "" --namespace "$NAMESPACE" --output "$BOND_DIR" "$schema"
    fi
done

echo "Bond schema compilation complete."
echo ""
echo "Generated files:"
ls -la "$BOND_DIR"/*_types.cs 2>/dev/null || echo "  (No generated files yet)"
