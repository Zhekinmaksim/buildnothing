#!/usr/bin/env node
// BUILD NOTHING setup: generate burner, arm the snitch, disarm.
//   node setup.mjs                 -> generate burner, wait for gas dust
//   node setup.mjs --arm <vowId>   -> install SessionStart hook + cron, first beat
//   node setup.mjs --disarm        -> remove hook + cron (relapses first if active)

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { execSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createPublicClient, http, formatEther } from "viem";
import { generatePrivateKey, privateKeyToAccount } from "viem/accounts";

// ---- config: fill after deploy -------------------------------------------
const CONTRACT = process.env.BN_CONTRACT ?? "0x0000000000000000000000000000000000000000";
const RPC = process.env.BN_RPC ?? "https://rpc.monad.xyz";
const CHAIN_ID = Number(process.env.BN_CHAIN_ID ?? 143);
// ---------------------------------------------------------------------------

const DIR = join(homedir(), ".buildnothing");
const CFG = join(DIR, "burner.json");
const SNITCH = resolve(dirname(fileURLToPath(import.meta.url)), "snitch.mjs");
const CLAUDE_SETTINGS = join(homedir(), ".claude", "settings.json");
const HOOK_CMD = `node ${SNITCH} relapse`;
const CRON_LINE = `13 9 * * * node ${SNITCH} heartbeat # buildnothing`;

const arg = process.argv[2];

function loadCfg() { return JSON.parse(readFileSync(CFG, "utf8")); }
function saveCfg(c) { mkdirSync(DIR, { recursive: true }); writeFileSync(CFG, JSON.stringify(c, null, 2)); }

function readSettings() {
  try { return JSON.parse(readFileSync(CLAUDE_SETTINGS, "utf8")); } catch { return {}; }
}
function writeSettings(s) {
  mkdirSync(dirname(CLAUDE_SETTINGS), { recursive: true });
  writeFileSync(CLAUDE_SETTINGS, JSON.stringify(s, null, 2));
}

function installHook() {
  const s = readSettings();
  s.hooks ??= {};
  s.hooks.SessionStart ??= [];
  const already = JSON.stringify(s.hooks.SessionStart).includes("buildnothing");
  if (!already) {
    s.hooks.SessionStart.push({
      matcher: "*",
      hooks: [{ type: "command", command: HOOK_CMD, timeout: 30 }],
    });
    writeSettings(s);
  }
  console.log("[arm] SessionStart hook installed -> every Claude Code session now reports you");
}

function removeHook() {
  const s = readSettings();
  if (s.hooks?.SessionStart) {
    s.hooks.SessionStart = s.hooks.SessionStart.filter(
      (h) => !JSON.stringify(h).includes("buildnothing") && !JSON.stringify(h).includes("snitch.mjs")
    );
    writeSettings(s);
  }
  console.log("[disarm] hook removed");
}

function installCron() {
  const current = spawnSync("crontab", ["-l"], { encoding: "utf8" }).stdout || "";
  if (!current.includes("# buildnothing")) {
    const next = current.trimEnd() + "\n" + CRON_LINE + "\n";
    execSync("crontab -", { input: next });
  }
  console.log("[arm] daily heartbeat cron installed (09:13 local)");
}

function removeCron() {
  const current = spawnSync("crontab", ["-l"], { encoding: "utf8" }).stdout || "";
  const next = current.split("\n").filter((l) => !l.includes("# buildnothing")).join("\n");
  execSync("crontab -", { input: next + "\n" });
  console.log("[disarm] cron removed");
}

async function main() {
  if (!arg) {
    // ---- step 1: burner ----
    if (existsSync(CFG)) {
      const c = loadCfg();
      console.log(`burner already exists: ${privateKeyToAccount(c.pk).address}`);
      console.log(`fund it with ~0.05 MON gas dust, then commit your vow and run:`);
      console.log(`  node setup.mjs --arm <vowId>`);
      return;
    }
    const pk = generatePrivateKey();
    const addr = privateKeyToAccount(pk).address;
    saveCfg({ pk, contract: CONTRACT, rpc: RPC, chainId: CHAIN_ID, vowId: null, armed: false });
    console.log("BUILD NOTHING - snitch burner generated");
    console.log(`  address: ${addr}`);
    console.log("");
    console.log("next:");
    console.log(`  1. send ~0.05 MON to ${addr} (gas for beats and betrayal)`);
    console.log(`  2. from your MAIN wallet call commit(duration, ${addr}) with your stake`);
    console.log(`  3. node setup.mjs --arm <vowId>`);
    return;
  }

  if (arg === "--arm") {
    const vowId = process.argv[3];
    if (!vowId) { console.error("usage: setup.mjs --arm <vowId>"); process.exit(1); }
    const c = loadCfg();
    const addr = privateKeyToAccount(c.pk).address;
    const pub = createPublicClient({ transport: http(c.rpc) });
    const bal = await pub.getBalance({ address: addr });
    if (bal === 0n) {
      console.error(`burner ${addr} has no gas. Fund it first.`);
      process.exit(1);
    }
    console.log(`burner balance: ${formatEther(bal)} MON`);
    c.vowId = vowId;
    c.armed = true;
    saveCfg(c);
    installHook();
    installCron();
    // first beat, immediately
    execSync(`node ${SNITCH} heartbeat`, { stdio: "inherit" });
    console.log("");
    console.log("armed. close this session and do not come back.");
    return;
  }

  if (arg === "--disarm") {
    if (existsSync(CFG)) {
      const c = loadCfg();
      if (c.armed) {
        console.log("active vow detected. Disarming counts as opening the box:");
        spawnSync("node", [SNITCH, "relapse"], { stdio: "inherit" });
        c.armed = false;
        saveCfg(c);
      }
    }
    removeHook();
    removeCron();
    console.log("snitch removed. It knew too much anyway.");
    return;
  }

  console.error("usage: setup.mjs [--arm <vowId>] [--disarm]");
  process.exit(1);
}

main();
