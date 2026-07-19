// CHG-0930 smoke test: verify the sandbox's `root` helper accepts the new
// pre-compaction memory flush target path (state/memory-flush/YYYY-MM-DD.md)
// without "path alias escape blocked".
//
// We use the actual OpenClaw dist build so the test reflects what the
// gateway will see at runtime.

import { a as root } from "/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/secure-temp-dir-DMUMnweR.js";
import path from "node:path";

const workspaceRoot = "/Users/ainchorsoc2a/.openclaw/workspace";
const today = new Date().toISOString().slice(0, 10);
const newRelativePath = `state/memory-flush/${today}.md`;
const oldRelativePath = `memory/${today}.md`;

console.log("=== CHG-0930 sandbox smoke test ===");
console.log("workspace root:", workspaceRoot);
console.log("new path (Option B):", newRelativePath);
console.log("legacy path (for comparison):", oldRelativePath);
console.log();

const handler = await root(workspaceRoot);

async function runOne(label, relativePath) {
  console.log(`--- ${label}: ${relativePath} ---`);
  const content = `\n# smoke test ${new Date().toISOString()}\nflush smoke test line\n`;
  try {
    await handler.append(relativePath, content, {
      mkdir: true,
      prependNewlineIfNeeded: true,
    });
    console.log(`  OK: appended to ${relativePath}`);
    return { ok: true };
  } catch (err) {
    console.log(`  FAIL: ${err?.message ?? err}`);
    return { ok: false, error: err };
  }
}

const newResult = await runOne("NEW", newRelativePath);
const oldResult = await runOne("LEGACY", oldRelativePath);

console.log();
console.log("=== Summary ===");
console.log("new path  :", newResult.ok ? "ACCEPTED ✓" : "REJECTED ✗");
console.log("old path  :", oldResult.ok ? "ACCEPTED" : "REJECTED (expected — hardlink causes alias escape)");

if (!newResult.ok) {
  process.exitCode = 1;
}
