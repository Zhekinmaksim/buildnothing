# BUILD NOTHING

**Stake MON on not vibecoding. A Claude Code skill snitches on you if you break.**

Submitted to Monad Spark - a hackathon about building anything.

## The problem (mine, specifically)

I ship across a dozen ecosystems and I have not written a function without
Claude Code in months. Half of crypto twitter is joking about forgetting how
to code. The jokes stopped being jokes. There was no way to quit that had
teeth - a promise to yourself costs nothing to break.

BUILD NOTHING makes it cost something, publicly.

## How it works

1. **Vow.** Call `commit(duration, snitchAddress)` with your stake (1-30 days,
   max 100 MON). One active vow per address.
2. **The snitch.** A Claude Code skill installs two things on your machine:
   - a `SessionStart` hook: the moment a Claude Code session starts, a
     dust-funded burner sends `relapse(vowId)`. Immediate, public, permanent.
   - a daily cron `heartbeat(vowId)`: proof the snitch is alive.
3. **The math.** The contract stores only `lastBeat` and a running
   `maxGap`. Any gap over 48h = slashed (killing the snitch is confessing).
   A relapse ping = slashed. Survive the full window = your stake back plus
   a pro-rata share of everything slashed from your weekly cohort.
4. **Epochs.** Vows settle in weekly cohorts. If nobody in a cohort survives,
   the pot rolls into a jackpot inherited by the next cohort's survivors.
   Donations to the contract seed the jackpot.
5. **The receipts.** Share cards render your streak as tally marks on a wall:
   `I BUILT NOTHING FOR 96 HOURS`, stamped CLEAN - or your count crossed out
   in red, stamped RELAPSED, with exactly how long you lasted. Both are
   worth posting. The relapse card possibly more.

## Threat model, honestly

- **Tamper-evident, not tamper-proof.** Deleting the snitch kills the
  heartbeat and auto-slashes you. Surgically removing only the hook while
  keeping the cron alive defeats the system. That is premeditated fraud
  against a small-stakes game between consenting degens; the 100 MON stake
  cap is sized for exactly this trust level.
- **Scope.** The snitch watches Claude Code on the machine it's installed on.
  It does not watch claude.ai in a browser or your second laptop. The
  enforced vow is "no vibecoding here"; the rest is honor and cohort pressure.
- **Offline grace.** 48h heartbeat gap allowance: a weekend away is safe,
  a week offline is indistinguishable from tampering and will be slashed.
- **Randomless.** No oracles, no VRF, no external dependencies. Every
  resolution path is a state check the chain performs on itself.

## Why Monad

Heartbeats are a transaction a day per participant, relapses and dust
funding more. At Monad gas prices the entire surveillance apparatus runs
on cents - a burner funded with 0.05 MON snitches for a month. The
economics of self-betrayal have never been this affordable.

## Repo layout

- `src/BuildNothing.sol` - the contract (11/11 tests passing)
- `test/BuildNothing.t.sol` - full lifecycle: survive, relapse, tamper,
  offline grace, rollover jackpot, late-resolve ratio freeze
- `skill/` - the Claude Code skill: SKILL.md, setup (arm/disarm), snitch runtime
- `cards/` - share card generator (SVG -> PNG)
- `web/` - vow page, cohort leaderboard, card sharing

## Deploy

```bash
forge script script/Deploy.s.sol --rpc-url $MONAD_RPC --private-key $PK --broadcast
```

Then set `BN_CONTRACT` in the skill environment and take your own vow.
Vow #1 belongs to the author. The repo you are reading was the last thing
she was allowed to build.
