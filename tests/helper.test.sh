#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/runtime"
printf 'inactive\n' >"$TEST_DIR/unit-state"

cat >"$TEST_DIR/bin/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state=$(cat "$SERVER_MODE_TEST_STATE")
case "$*" in
  *"is-active --quiet"*) [[ $state == active ]] ;;
  *"--property=LoadState --value"*)
    [[ $state == active ]] && printf 'loaded\n' || printf 'not-found\n'
    ;;
  *" stop "*|*" stop "|*" stop" ) printf 'inactive\n' >"$SERVER_MODE_TEST_STATE" ;;
  *"is-active"*) [[ $state == active ]] ;;
  *) exit 0 ;;
esac
SH

cat >"$TEST_DIR/bin/systemd-run" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'active\n' >"$SERVER_MODE_TEST_STATE"
printf '%s\n' "$*" >"$SERVER_MODE_TEST_RUN_ARGS"
SH

chmod +x "$TEST_DIR/bin/systemctl" "$TEST_DIR/bin/systemd-run"

export SERVER_MODE_RUNTIME_DIR="$TEST_DIR/runtime"
export SERVER_MODE_SYSTEMCTL_BIN="$TEST_DIR/bin/systemctl"
export SERVER_MODE_SYSTEMD_RUN_BIN="$TEST_DIR/bin/systemd-run"
export SERVER_MODE_TEST_STATE="$TEST_DIR/unit-state"
export SERVER_MODE_TEST_RUN_ARGS="$TEST_DIR/run-args"
export SERVER_MODE_SELF="$ROOT/server-mode"

if "$ROOT/server-mode" status >/dev/null 2>&1; then
  echo "expected inactive status to return non-zero" >&2
  exit 1
fi

inactive_json=$("$ROOT/server-mode" status --json)
jq -e '.active == false and .lastReason == "never-started"' <<<"$inactive_json" >/dev/null

if "$ROOT/server-mode" on --scope invalid >/dev/null 2>&1; then
  echo "expected invalid scope to fail" >&2
  exit 1
fi

"$ROOT/server-mode" on --scope lid --duration-minutes 30 --lease-seconds 45
active_json=$("$ROOT/server-mode" status --json)
jq -e '.active == true and .scope == "lid" and .remainingSeconds > 0' <<<"$active_json" >/dev/null
grep -q -- '--unit=omarchy-server-mode' "$TEST_DIR/run-args"

"$ROOT/server-mode" renew
[[ -e $TEST_DIR/runtime/heartbeat ]]

"$ROOT/server-mode" off --reason manual
inactive_json=$("$ROOT/server-mode" status --json)
jq -e '.active == false and .lastReason == "manual"' <<<"$inactive_json" >/dev/null

echo "Helper tests passed"
