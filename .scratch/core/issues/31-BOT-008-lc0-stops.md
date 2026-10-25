# BOT-008: Say so when Lc0 stops
Stage: to-review
Blocked by: BOT-004
Review: agent
Difficulty: normal

- Primary files:
  - engine/uci.gd
  - ui/main.gd
  - tests/test_uci.gd

#### What to build

If Lc0 dies during a game (a crash, or a net it cannot load), the player is told and sent back to the setup screen, instead of waiting forever for Maia's move. Today `engine/uci.gd` never notices: requests stay queued and `available` stays true. Found in BOT-002's review, carried by BOT-004 (see both Resolutions).

#### Acceptance criteria

1. When the Lc0 process exits on its own, the next `poll()` leaves `available` false, `error` set to a message saying Lc0 stopped, the queue empty, and emits `stopped`. The app's own `stop()` does not emit it.
2. If Lc0 reports a stdout line beginning `error `, including failure to load the requested net after `readyok`, the bridge stops the child and reaches c1's unavailable/error/empty-queue/`stopped` state. It discards remaining buffered responses and emits no policy from the failed request. A missing net is exercised with `set_level` followed by `request_policy`, since loading may fail only when searching.
3. On `stopped`, `ui/main.gd` ends the game and shows the setup screen with `error` in place of Start, as BOT-004 c6 does when Lc0 is missing.
4. Tested live, skipped where `engine/` lacks Lc0 as in BOT-002 c7: killing Lc0's `pid` outside `stop()` gives exactly one `stopped` within 10 s of polling. Separately, start Lc0, select a known absent absolute net path, queue a policy request, and poll: exactly one `stopped` arrives within 10 s, with no policy emitted.

#### Verification

    Manual: in a game against Maia, end lc0.exe in Task Manager; the setup screen shows the error.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_uci.gd`: the two live cases of c4. Red because the bridge never reports a stop.

## Comments

- 2026-10-24 Created at BOT-004's close (Proxy decided (opus), BOT-004 ## Comments). No general reply timeout is asked for: the first net load took 15.5 s on a loaded machine (BOT-004 Review), so a short one would kill a healthy Lc0. If c2 needs one, put it on the `readyok` wait only and record the value here.
- The proxy did not check what Lc0 v0.32.1 does with a `WeightsFile` that does not exist (exit, an `error` line, or silence), so c2 states the outcome, not the mechanism. If Lc0 instead finds another net and answers `readyok`, c2 cannot hold: stage 2 stops and asks.
- If Bruno answers PolicyTemperature (BOT-007 ## Comments) before this ticket starts, stage 1 may fold its `setoption` line into a criterion here, since `start()` is in this file.
- 2026-10-25 Stage 2 pre-test inspection: `ui/main.gd` owns the bridge and starts/loads it; `bot/maia_player.gd` queues policies and may emit a delayed move after a timer. The live UCI seam approved above covers external process death, repeated polling, queued requests, restart, and intentional shutdown. UI handling must freeze clocks, invalidate delayed Maia moves, cancel board interaction, and account for an engine exit while `_start()` awaits the opening catalog. BOT-007 leaves PolicyTemperature at the shared Lc0 default; no setting change is authorized here.
- 2026-10-25 Proxy decided (gpt-6-astra high, fallback): fail closed on Lc0 stdout `error ` even after `readyok`, and exercise missing weights through the next policy request — installed Lc0 v0.32.1 explicitly rejects the requested file but remains alive and returns a policy, so readiness cannot prove the selected net loaded. This supersedes the earlier fallback/readyok uncertainty. Clarified c2/c4 as drafted by the proxy; no new files or seams and no production timeout.
- 2026-10-25 Stage 2, cycle 1: test-only `cea3f3f` is red because the bridge lacks `stopped` (full suite: **229 passed, 1 failed**, exit 1). Production-only `ef4c5e2` makes all **6 focused UCI tests pass**, live: external kill, no abandoned policy, restart without replaying queued requests, cleared error, and intentional shutdown without another signal. `poll()` detects child death before consuming responses; cleanup resets queued commands, reply state, policy buffers, pipes, reader threads and pid. Calls made while unavailable do not queue work.
- 2026-10-25 Stage 2, cycle 2: test-only `fd69bd4` is red on the real missing-net case (**6 focused tests passed, 1 failed**, exit 1): no stop signal, `available` stays true, and a fallback policy is emitted. The live transcript was `uciok`, `readyok`, `error Cannot read weights from <absent path>`, then normal policy statistics and `bestmove e2e4`. After the proxy clarification, production `54f3b88` stops on that explicit stdout error, preserves its diagnostic and returns immediately without processing the rest of the batch: **7 focused tests passed, 0 failed**. No stderr interpretation or general reply timeout was added.
- 2026-10-25 Scene verification, using temporary scripts outside the repository: instantiated the real `ui/main.tscn` with isolated history and preferences, started a game, then (a) killed its real Lc0 pid externally and (b) selected a nonexistent net before requesting a move. Both showed setup with the bridge error replacing Start, detached all clocks, disabled board input, hid review, refused another start and preserved the moves at abort. A separate check using the existing held-engine/manual-timer fixture confirmed that finishing an already scheduled Maia wait after `stopped` cannot play its move. No fabricated game result or history write. These checks ran headless; interactive visual inspection in Task Manager remains pending.
- 2026-10-25 Gate on committed `54f3b88`: `godot --headless -s tests/run.gd`, **231 passed, 0 failed**, exit 0. All 7 UCI tests ran live, with no SKIP. The official helper generated the receipt below. Final diff inspection confirmed only the three Primary files and this ticket changed, with test/production commits separated and no generated artifacts. Stage 2 hands off here; independent review and integration are stage 3.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\BOT-008-54f3b88-gate.json

Acceptance: pending | Scene verification above establishes the real scene's error/setup behavior headlessly for both failure modes; interactive visual inspection of the Task Manager scenario remains pending.
Disclosure: decision | none | Proxy clarification above: explicit Lc0 stdout `error ` is fatal even after `readyok`, preventing fallback policy from an unverified net. PolicyTemperature remains unchanged, and no general timeout is introduced.
Disclosure: pending | release | Interactive visual inspection from Verification remains pending; both real-process failure cases and the resulting scene state passed automated headless verification above.
