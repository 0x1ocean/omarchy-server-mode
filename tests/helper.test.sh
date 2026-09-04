#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf -- "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/runtime"
printf 'inactive\n' >"$TEST_DIR/unit-state"
printf 'inactive\n' >"$TEST_DIR/ssh-state"
printf 'stopped\n' >"$TEST_DIR/tailscale-state"
: >"$TEST_DIR/processes"

cat >"$TEST_DIR/bin/systemctl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ $* == *sshd.service* ]]; then
  state=$(cat "$SERVER_MODE_TEST_SSH_STATE")
  [[ $* == *"is-active --quiet"* && $state == active ]]
  exit
fi
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

cat >"$TEST_DIR/bin/tailscale" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == status && ${2:-} == --json ]] || exit 2
case "$(cat "$SERVER_MODE_TEST_TAILSCALE_STATE")" in
  running)
    printf '%s\n' '{"BackendState":"Running","Self":{"Online":true,"TailscaleIPs":["100.64.0.8","fd7a:115c:a1e0::8"],"DNSName":"test.tailnet.ts.net."}}'
    ;;
  offline)
    printf '%s\n' '{"BackendState":"Running","Self":{"Online":false,"TailscaleIPs":["100.64.0.8"],"DNSName":"test.tailnet.ts.net."}}'
    ;;
  stopped)
    printf '%s\n' '{"BackendState":"Stopped","Self":{"Online":false,"TailscaleIPs":["100.64.0.8"],"DNSName":"test.tailnet.ts.net."}}'
    ;;
  *) exit 1 ;;
esac
SH

cat >"$TEST_DIR/bin/sshd" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == -T ]] || exit 2
printf 'port 2222\n'
SH

cat >"$TEST_DIR/bin/ip" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '[{"ifname":"eth0","addr_info":[{"scope":"global","local":"192.0.2.10"}]}]'
SH

cat >"$TEST_DIR/bin/pgrep" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
name=${!#}
grep -Fxq -- "$name" "$SERVER_MODE_TEST_PROCESSES"
SH

for provider in sunshine rustdesk wayvnc; do
  cat >"$TEST_DIR/bin/$provider" <<'SH'
#!/usr/bin/env bash
exit 0
SH
done

cat >"$TEST_DIR/bin/systemd-run" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'active\n' >"$SERVER_MODE_TEST_STATE"
printf '%s\n' "$*" >"$SERVER_MODE_TEST_RUN_ARGS"
SH

chmod +x "$TEST_DIR/bin/systemctl" "$TEST_DIR/bin/systemd-run" \
  "$TEST_DIR/bin/tailscale" "$TEST_DIR/bin/sshd" "$TEST_DIR/bin/ip" \
  "$TEST_DIR/bin/pgrep" "$TEST_DIR/bin/sunshine" "$TEST_DIR/bin/rustdesk" \
  "$TEST_DIR/bin/wayvnc"

export SERVER_MODE_RUNTIME_DIR="$TEST_DIR/runtime"
export SERVER_MODE_SYSTEMCTL_BIN="$TEST_DIR/bin/systemctl"
export SERVER_MODE_SYSTEMD_RUN_BIN="$TEST_DIR/bin/systemd-run"
export SERVER_MODE_TEST_STATE="$TEST_DIR/unit-state"
export SERVER_MODE_TEST_SSH_STATE="$TEST_DIR/ssh-state"
export SERVER_MODE_TEST_TAILSCALE_STATE="$TEST_DIR/tailscale-state"
export SERVER_MODE_TEST_PROCESSES="$TEST_DIR/processes"
export SERVER_MODE_TEST_RUN_ARGS="$TEST_DIR/run-args"
export SERVER_MODE_SELF="$ROOT/server-mode"
export SERVER_MODE_IP_BIN="$TEST_DIR/bin/ip"
export SERVER_MODE_PGREP_BIN="$TEST_DIR/bin/pgrep"
export SERVER_MODE_TAILSCALE_BIN="$TEST_DIR/bin/tailscale"
export SERVER_MODE_SSHD_BIN="$TEST_DIR/bin/sshd"
export SERVER_MODE_SUNSHINE_BIN="$TEST_DIR/bin/sunshine"
export SERVER_MODE_RUSTDESK_BIN="$TEST_DIR/bin/rustdesk"
export SERVER_MODE_WAYVNC_BIN="$TEST_DIR/bin/wayvnc"

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

# A stopped Tailscale backend still returns successful JSON and stale addresses.
# It must be shown as disconnected, and Automatic must fall back to LAN.
diagnostics_json=$("$ROOT/server-mode" diagnostics --json)
jq -e '
  .lanIp == "192.0.2.10" and
  .tailscale == {installed:true,active:false,state:"Stopped",ip:"",name:""} and
  .ssh == {installed:true,active:false,port:2222} and
  ([.remoteDesktop[] | .installed] | all) and
  ([.remoteDesktop[] | .active] | any | not)
' <<<"$diagnostics_json" >/dev/null

# BackendState alone is insufficient: the local Tailscale node must be online.
printf 'offline\n' >"$TEST_DIR/tailscale-state"
diagnostics_json=$("$ROOT/server-mode" diagnostics --json)
jq -e '.tailscale.state == "Running" and .tailscale.active == false and .tailscale.ip == ""' \
  <<<"$diagnostics_json" >/dev/null

# Validate live Tailscale, active SSH, and each supported remote-screen process.
printf 'running\n' >"$TEST_DIR/tailscale-state"
printf 'active\n' >"$TEST_DIR/ssh-state"
for provider in sunshine rustdesk wayvnc; do
  printf '%s\n' "$provider" >"$TEST_DIR/processes"
  diagnostics_json=$("$ROOT/server-mode" diagnostics --json)
  jq -e --arg provider "$provider" '
    .tailscale.active == true and
    .tailscale.state == "Running" and
    .tailscale.ip == "100.64.0.8" and
    .tailscale.name == "test.tailnet.ts.net" and
    .ssh == {installed:true,active:true,port:2222} and
    .remoteDesktop[$provider] == {installed:true,active:true}
  ' <<<"$diagnostics_json" >/dev/null
done

# Missing optional programs must never be reported as installed or active.
export SERVER_MODE_TAILSCALE_BIN="$TEST_DIR/bin/missing-tailscale"
export SERVER_MODE_SSHD_BIN="$TEST_DIR/bin/missing-sshd"
export SERVER_MODE_SUNSHINE_BIN="$TEST_DIR/bin/missing-sunshine"
export SERVER_MODE_RUSTDESK_BIN="$TEST_DIR/bin/missing-rustdesk"
export SERVER_MODE_WAYVNC_BIN="$TEST_DIR/bin/missing-wayvnc"
printf 'inactive\n' >"$TEST_DIR/ssh-state"
: >"$TEST_DIR/processes"
diagnostics_json=$("$ROOT/server-mode" diagnostics --json)
jq -e '
  .tailscale.installed == false and .tailscale.active == false and
  .ssh.installed == false and .ssh.active == false and
  ([.remoteDesktop[] | .installed] | any | not) and
  ([.remoteDesktop[] | .active] | any | not)
' <<<"$diagnostics_json" >/dev/null

echo "Helper tests passed"
