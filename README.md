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

## Live deployment

- App: https://buildnothing.fun
- Network: Monad Mainnet (`chainId` 143)
- Contract: `0x380b02992E2E0Be93eA31841a0E911D85DE77842`
- Source verification: full match on MonadVision/Sourcify
  `https://sourcify-api-monad.blockvision.org/repository/contracts/full_match/143/0x380b02992E2E0Be93eA31841a0E911D85DE77842/metadata.json`

## How to use

The web app handles the on-chain vow. The local snitch handles proof that the
vow was not bypassed.

1. **Generate a snitch burner.**

   ```bash
   node skill/scripts/setup.mjs
   ```

   This creates `~/.buildnothing/burner.json` and prints a burner address.
   Fund that burner with a small amount of MON for gas, for example `0.05 MON`.
   The burner is not your stake wallet; it only sends `heartbeat()` and
   `relapse()` transactions.

2. **Take the vow on the website.**

   Open https://buildnothing.fun, choose duration and stake, paste the burner
   address as the snitch address, then click `Connect wallet & commit`.
   The stake is paid from your normal wallet.

3. **Arm the snitch.**

   After the transaction confirms, use the returned vow id:

   ```bash
   BN_CONTRACT=0x380b02992E2E0Be93eA31841a0E911D85DE77842 node skill/scripts/setup.mjs --arm <vowId>
   ```

   Arming installs a Claude Code `SessionStart` hook, installs a daily
   heartbeat cron/launchd job, and sends the first heartbeat immediately.

4. **Do not open Claude Code until the vow ends.**

   Opening Claude Code sends `relapse(vowId)` from the burner. Killing the
   heartbeat for more than 48 hours lets the contract slash the vow as
   tampered.

5. **Check or share a vow.**

   Use the `Check a vow` form on the website with either the vow id or wallet
   address. The page reads Monad Mainnet live state and can generate a share
   card.

To clean up after a demo:

```bash
node skill/scripts/setup.mjs --disarm
```

If a vow is still active, disarming intentionally reports a relapse first.

## Judge walkthrough

For a fast review, judges can:

1. Open https://buildnothing.fun and inspect the live contract link in the
   footer.
2. Check vow `1` in the `Check a vow` form.
3. Review the verified contract source using the `Live deployment` link above.
4. Run `forge test` locally; the contract test suite should pass `11/11`.

## Repo layout

- `src/BuildNothing.sol` - the contract (11/11 tests passing)
- `test/BuildNothing.t.sol` - full lifecycle: survive, relapse, tamper,
  offline grace, rollover jackpot, late-resolve ratio freeze
- `skill/` - the Claude Code skill: SKILL.md, setup (arm/disarm), snitch runtime
- `cards/` - share card generator (SVG -> PNG)
- `web/` - vow page, cohort leaderboard, card sharing

## Roadmap

The current version is intentionally honest rather than frictionless: a vow
only has teeth once the local snitch is armed, and that still requires a few
manual steps. The next milestone is to keep the same threat model while making
the setup feel closer to "stake MON and wait".

1. **Local snitch companion.** Ship a tiny localhost helper that the user runs
   once. It generates the burner locally, stores the private key in
   `~/.buildnothing`, and exposes only a narrow API to the website:
   `status`, `generate`, `arm`, `disarm`, and `heartbeat`.
2. **Safe website pairing.** Add a `Connect local snitch` flow. The helper
   prints a pairing code, the user enters it on the site, and the site receives
   only the burner address and status - never the burner private key.
3. **Auto-fill and auto-arm.** After pairing, the site fills the snitch address,
   the user stakes from their normal wallet, and the helper arms the returned
   vow id automatically.
4. **Security guardrails.** The helper must listen only on `127.0.0.1`, accept
   only the official origin, require the pairing token for side effects, and
   refuse arbitrary transactions. It may sign only `heartbeat(vowId)` and
   `relapse(vowId)` for the deployed BuildNothing contract after verifying
   `vow.snitch == burnerAddress`.
5. **Clear product split.** Keep the manual CLI as a transparent fallback.
   The website should explain the core rule plainly: no snitch, no proof. The
   main wallet stays in Rabby/Phantom; the snitch burner only holds gas dust.
6. **Non-crypto charity mode.** Add a walletless path for users who do not
   hold MON. Instead of calling it a stake, frame it as a card-based charity
   pledge: the user chooses a nonprofit, chooses an amount, and a relapse
   triggers a donation workflow through Pledge. The UI must be explicit that
   donations are processed by Pledge and disbursed to nonprofits through
   Pledge's payout schedule, not instantly routed on-chain. Crypto users keep
   the trustless MON stake mode; non-crypto users get a familiar card flow with
   charitable consequences.

## Deploy

```bash
forge script script/Deploy.s.sol --rpc-url $MONAD_RPC --private-key $PK --broadcast
```

Then set `BN_CONTRACT` in the skill environment and take your own vow.
Vow #1 belongs to the author. The repo you are reading was the last thing
she was allowed to build.
