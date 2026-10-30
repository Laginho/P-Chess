# REV-001: A UCI bridge that can run a second engine
Stage: done
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - engine/uci.gd
  - ui/main.gd (only where it builds the bridge)
  - bot/maia_player.gd (only where it builds or reads the bridge)
  - tests/test_uci.gd

#### What to build

Prefactor, no behaviour change for Maia. `engine/uci.gd` hardcodes Lc0: its path, its error messages and its Lc0-only setup (`VerboseMoveStats`, policy parsing). Make the engine a parameter so a second instance can run Stockfish (REV-002), while Lc0's instance behaves exactly as today.

#### Acceptance criteria

1. A bridge is built for a named engine: its exe path under the search dirs and its display name ("Lc0", "Stockfish"). Missing-engine and stopped-engine messages use that name and still point at `scripts/fetch-engine.ps1`.
2. The Lc0-specific setup and the policy request stay available to the Maia bridge only; the Stockfish bridge sends neither.
3. A bridge can forward every raw `info` line of a search, with the final `bestmove`, to its caller, so REV-002 can parse MultiPV lines without changing the bridge again.
4. Two bridges can run at once, each with its own process, readers and queue; stopping one leaves the other running.
5. Every existing test passes unchanged except for construction call sites.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_uci.gd`: a bridge for "Stockfish" with no exe reports "Stockfish is missing (engine/stockfish/stockfish.exe)…" (red: always says Lc0); a fake-process bridge forwards info lines and bestmove to a callback (red: no forwarding).

## Comments

- 2026-10-30 Written from spec §15.3 ("through the same bridge as Lc0").
- Stage 2: missing-engine and search-forwarding tests failed before implementation; the Stockfish Maia-command guard was checked with a failing mutation. The two-instance regression test uses two live Lc0 processes and verifies that the survivor answers after the other stops.
- Verification: `godot --headless -s tests/run.gd` passed, 274 passed, 0 failed, no skips, on production commit `998bb5c`.
- Acceptance: unknown
- Stage 3: updated the queue-step and engine-lookup comments to describe the new callback field and parameterized path. Documentation only; no behavior changed.

Gate evidence: C:\Users\bruno\AppData\Local\Temp\REV-001-stage3-gate.json

#### Resolution (2026-10-30)

Verdict: Approve

- Standards: 0 documented violations and 0 relevant heuristic smells. Spec: 0 findings. Both axes independently reviewed the complete `27d1464...fed3528` diff. All 3 changed files were reviewed manually (100%, none skipped), including the `.gd` and `.md` files OCR excluded as `unsupported_ext`. The final editorial correction and the REV-002 tracker note were also reviewed.
- Criterion 1: passed. The configured executable path is searched under each search directory; missing/stopped messages use the configured display name and reference the fetch script.
- Criterion 2: passed. Stockfish skips `VerboseMoveStats`, Maia weights and policy requests; default Lc0 construction preserves Maia's setup.
- Criterion 3: passed. The search callback receives raw `info` lines and the final `bestmove`; generic searches do not emit Maia policies.
- Criterion 4: passed. Process, reader threads, mutex, pending lines, command queue and callback are per bridge. The live two-Lc0 test stops one process and obtains a policy from the survivor.
- Criterion 5: passed. Existing tests are unchanged; all test changes are additions. The final gate passed the existing suite and the new cases.
- Examined callers and failure paths: `ui/main.gd` default construction, startup and stopped-engine UI; `bot/maia_player.gd` net lookup and FIFO policy consumers; handshake, queued requests, missing executable, engine exit, missing weights, cleanup and restart. No changed file was left unexamined. Actual Stockfish execution and its future analysis consumer were not exercised here.
- Red/green evidence: stage 2 recorded failing missing-engine and forwarding cases before implementation, plus a failing mutation for the Maia-command guard. Review verified separate test/production commits (`eb9059a` / `6f63fe2`, `e4c5a1d` / `204b2a8`, and later test-only regression additions). Historical red runs were not replayed in stage 3.
- Review correction: `43411c0` updates only the stale queue-step and engine-lookup comments in production code. No behavior was authored in review. The open [REV-002](53-REV-002-analysis-engine-and-files.md) now records its outstanding `stop` / `id name` seam and Primary-files scope decision.
- Verification: `godot --headless -s tests/run.gd`, 274 passed, 0 failed, 0 skips, exit 0 on `43411c00e213016b2e4f63ca223400f04181ccfc`. Receipt and log SHA-256 verified; the log is `C:\Users\bruno\AppData\Local\Temp\REV-001-stage3-gate.log`. No production changes followed that run.
- Integration: rebased onto `sweatshop/analysis/2026-10-30-1831` (already current), then merged without squash as `513acab`. No PR or push is part of this session-stage handoff.

Acceptance: unknown
Disclosure: pending | release | [Product QA in spec section 15.1](../../../docs/spec.md#151-release-and-tickets) remains Bruno's release acceptance; the headless bridge checks and live Lc0 checks do not establish that acceptance. Stockfish game analysis remains the open [REV-002](53-REV-002-analysis-engine-and-files.md) deliverable.
