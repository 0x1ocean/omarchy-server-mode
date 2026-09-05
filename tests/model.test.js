const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const source = fs
  .readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\.pragma library\s*/m, "");
const context = { module: { exports: {} }, console };
vm.runInNewContext(source, context, { filename: "Model.js" });
const model = context.module.exports;

assert.equal(model.normalizedScope("Lid only"), "lid");
assert.equal(model.normalizedScope("full"), "full");
assert.equal(model.scopeLabel("lid"), "Lid only");
assert.equal(model.durationMinutes(-1), 0);
assert.equal(model.durationMinutes(120), 120);
assert.equal(model.durationLabel(0), "Until logout");
assert.equal(model.durationLabel(90), "1 h 30 min");
assert.equal(model.remainingLabel(61), "2 min left");
assert.equal(model.reasonLabel("lease-expired"), "Shell lease expired");

const diagnostics = {
  hostname: "arc",
  user: "roma",
  lanIp: "192.0.2.10",
  tailscale: { active: true, ip: "100.64.0.2", name: "arc.example.ts.net" },
  ssh: { active: true, port: 2222 },
};
assert.equal(model.preferredAddress(diagnostics, "Automatic"), "100.64.0.2");
assert.equal(model.preferredAddress(diagnostics, "LAN"), "192.0.2.10");
assert.equal(model.sshCommand(diagnostics, "LAN"), "ssh -p 2222 roma@192.0.2.10");
assert.equal(model.connectionSummary(diagnostics), "Tailscale + SSH ready");

const disconnectedTailscale = {
  hostname: "arc",
  user: "roma",
  lanIp: "192.0.2.10",
  tailscale: { installed: true, active: false, ip: "100.64.0.2", name: "stale.ts.net" },
  ssh: { installed: true, active: true, port: 22 },
};
assert.equal(model.preferredAddress(disconnectedTailscale, "Automatic"), "192.0.2.10");
assert.equal(model.preferredAddress(disconnectedTailscale, "Tailscale"), "");
assert.equal(model.connectionSummary(disconnectedTailscale), "SSH ready on LAN");

assert.equal(model.providerLabel({ installed: false, active: false }), "Not installed");
assert.equal(model.providerLabel({ installed: true, active: false }), "Installed");
assert.equal(model.providerLabel({ installed: true, active: true }), "Running");
assert.equal(model.hasRemoteDesktop({ remoteDesktop: {} }), false);
assert.equal(model.hasRemoteDesktop({
  remoteDesktop: { sunshine: { installed: true, active: false } },
}), true);
assert.equal(model.remoteDesktopSummary({ remoteDesktop: {} }), "Not configured");
assert.equal(model.remoteDesktopSummary({
  remoteDesktop: {
    sunshine: { installed: true, active: false },
    rustdesk: { installed: true, active: false },
  },
}), "Sunshine, RustDesk");
assert.equal(model.remoteDesktopSummary({
  remoteDesktop: {
    sunshine: { installed: true, active: false },
    wayvnc: { installed: true, active: true },
  },
}), "WayVNC running");
assert.deepEqual(model.parseObject("not-json", { ok: false }), { ok: false });

assert.equal(model.parseDiagnostics(JSON.stringify(diagnostics)).hostname, "arc");
for (const invalid of ["", "not-json", "[]", "null", '{"hostname":42}', " ".repeat(4097)]) {
  assert.equal(Object.keys(model.parseDiagnostics(invalid)).length, 0);
}
console.log("Model tests passed");
