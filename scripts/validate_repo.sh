#!/usr/bin/env bash
set -euo pipefail
[ -f project.yml ]
[ -f Irfaali/App/IrfaaliApp.swift ]
[ -f Irfaali/Resources/AppIconSource.b64 ]
for file in $(find Irfaali IrfaaliTests -name '*.swift' -print); do
  swiftc -frontend -parse "$file" >/dev/null
done
echo "Repository structure and Swift syntax parse checks passed."
