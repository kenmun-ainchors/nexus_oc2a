// CHG-0930 build plan test (via the _chg0930_test export).
import { _chg0930_test as buildMemoryFlushPlan } from "/Users/ainchorsoc2a/local/lib/node_modules/openclaw/dist/extensions/memory-core/index.js";

console.log("=== CHG-0930 buildMemoryFlushPlan test ===");
const plan = buildMemoryFlushPlan({ cfg: {}, nowMs: Date.now() });
console.log("relativePath     :", plan?.relativePath);
console.log();
console.log("prompt:");
console.log(plan?.prompt);
console.log();
console.log("systemPrompt:");
console.log(plan?.systemPrompt);
console.log();

const ok = plan?.relativePath === "state/memory-flush/2026-07-19.md"
  && plan?.prompt?.includes("state/memory-flush/2026-07-19.md")
  && plan?.systemPrompt?.includes("state/memory-flush/2026-07-19.md")
  && !plan?.prompt?.includes("memory/2026-07-19.md")
  && !plan?.systemPrompt?.includes("memory/2026-07-19.md");

console.log(ok ? "PASS: plan uses state/memory-flush/ and prompts match" : "FAIL: plan or prompts do not match expected new path");
process.exitCode = ok ? 0 : 1;
