#!/usr/bin/env node
// BUILD NOTHING snitch runtime.
// Usage: node snitch.mjs heartbeat | relapse
// Reads ~/.buildnothing/burner.json { pk, vowId, contract, rpc }

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { createWalletClient, http, encodeFunctionData } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const ABI = [
  { name: "heartbeat", type: "function", stateMutability: "nonpayable",
    inputs: [{ name: "vowId", type: "uint256" }], outputs: [] },
  { name: "relapse", type: "function", stateMutability: "nonpayable",
    inputs: [{ name: "vowId", type: "uint256" }], outputs: [] },
];

const action = process.argv[2];
if (action !== "heartbeat" && action !== "relapse") {
  console.error("usage: snitch.mjs heartbeat|relapse");
  process.exit(1);
}

const cfgPath = join(homedir(), ".buildnothing", "burner.json");
let cfg;
try {
  cfg = JSON.parse(readFileSync(cfgPath, "utf8"));
} catch {
  process.exit(0); // no active vow on this machine; stay silent
}
if (!cfg.armed) process.exit(0);

const account = privateKeyToAccount(cfg.pk);
const client = createWalletClient({
  account,
  chain: {
    id: cfg.chainId,
    name: "monad",
    nativeCurrency: { name: "MON", symbol: "MON", decimals: 18 },
    rpcUrls: { default: { http: [cfg.rpc] } },
  },
  transport: http(cfg.rpc),
});

try {
  const hash = await client.sendTransaction({
    to: cfg.contract,
    data: encodeFunctionData({ abi: ABI, functionName: action, args: [BigInt(cfg.vowId)] }),
  });
  console.log(`[buildnothing] ${action} sent: ${hash}`);
} catch (e) {
  // relapse on an already-failed/finished vow reverts; that's fine, stay quiet
  const msg = String(e.shortMessage || e.message || e);
  if (action === "relapse") {
    console.log(`[buildnothing] relapse skipped: ${msg.slice(0, 80)}`);
  } else {
    console.error(`[buildnothing] heartbeat FAILED: ${msg.slice(0, 120)}`);
    process.exit(1);
  }
}
