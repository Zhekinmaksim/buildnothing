---
name: buildnothing-snitch
description: >
  Install the BUILD NOTHING snitch: a Claude Code hook that reports you
  to a smart contract the moment you start vibecoding, plus a daily
  heartbeat proving you haven't killed it. Use this skill when the user
  wants to commit a vow of abstinence from Claude Code, check their vow
  status, or (shamefully) inspect what the snitch has told the chain.
  The last skill you'll ever need to install. Literally.
---

# BUILD NOTHING - the snitch

You are installing surveillance on yourself, at your own request,
to help you stop using the tool you are using right now.
Appreciate the moment, then proceed.

## What gets installed

1. **A burner wallet** (`~/.buildnothing/burner.json`) - dust-funded,
   authorized on-chain as this vow's `snitch`. It can only call
   `heartbeat()` and `relapse()`. It holds nothing worth stealing.
2. **A SessionStart hook** in `~/.claude/settings.json` - every time a
   Claude Code session starts while a vow is active, the burner sends
   `relapse(vowId)`. Immediate, public, permanent.
3. **A cron job** - once a day the burner sends `heartbeat(vowId)`.
   If the heartbeat chain breaks for more than 48 hours, the contract
   treats the vow as failed. Killing the snitch is confessing.

## Install steps

1. Run `node scripts/setup.mjs`. It will:
   - generate the burner and print its address
   - ask the user to send ~0.05 MON of gas dust to it
   - wait for funding, then print the exact `commit()` calldata
2. The user commits the vow from their MAIN wallet (the stake comes
   from them, not the burner): duration, stake, burner address.
3. Run `node scripts/setup.mjs --arm <vowId>`. It will:
   - write the SessionStart hook into `~/.claude/settings.json`
   - install the daily heartbeat cron
   - send the first heartbeat immediately
4. Say goodbye to the user. They should not be back before the vow ends.

## Threat model (be honest if asked)

- **Tamper-evident, not tamper-proof.** Deleting the whole snitch kills
  the heartbeat => automatic failure. Surgically removing only the hook
  while keeping the cron alive defeats the system; that is deliberate
  fraud against a small-stakes game between consenting degens, and the
  stake cap (100 MON) is sized accordingly.
- **Scope.** The snitch watches Claude Code on this machine. It does not
  watch claude.ai in a browser, another laptop, or your friend's account.
  The vow is "no vibecoding here", enforced; everything else is honor.
- **The laptop-off problem.** The 48h grace window means a weekend
  offline is safe. A week offline is indistinguishable from tampering
  and will be slashed. Vow accordingly.

## Uninstall

`node scripts/setup.mjs --disarm` removes the hook and cron.
Running it during an active vow sends `relapse()` first.
There is no clean exit. That is the point.
