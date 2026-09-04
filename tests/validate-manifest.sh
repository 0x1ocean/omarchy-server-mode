#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST="$ROOT/manifest.json"

jq -e '
  .schemaVersion == 1
  and (.id | test("^[a-z0-9][a-z0-9._-]*$") and (startswith("omarchy.") | not))
  and (.name | length > 0)
  and (.version | length > 0)
  and (.kinds | index("service") != null)
  and (.kinds | index("bar-widget") != null)
  and (.entryPoints.service == "Service.qml")
  and (.entryPoints.barWidget == "BarWidget.qml")
' "$MANIFEST" >/dev/null

while IFS= read -r entry; do
  [[ -f $ROOT/$entry ]] || {
    echo "missing manifest entry point: $entry" >&2
    exit 1
  }
done < <(jq -r '.entryPoints[]' "$MANIFEST")

echo "Manifest tests passed"
