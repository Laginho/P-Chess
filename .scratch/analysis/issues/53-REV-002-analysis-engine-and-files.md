# REV-002: Analyse a game with Stockfish and store the result
Stage: done
Blocked by: CI-004, REV-001
Review: agent
Difficulty: hard
Gate evidence: C:\Users\bruno\AppData\Local\Temp\rev002-gate.json
Acceptance: pending | Run scripts/analyse.gd on a real saved game and check the JSON and elapsed time; a two-ply synthetic PGN was verified locally with Stockfish 19 in 0.9 s, and its SHA-256 was unchanged.

- Primary files:
  - New: engine/analyser.gd
  - New: scripts/analyse.gd (headless: analyse one PGN, write its JSON)
  - core/tunables.gd (if BOT-011 has not created it yet, create it)
  - engine/uci.gd (MultiPV parsing if appropriate; expose handshake `id name` and provide in-search `stop_search()`, preserving process-killing `stop()` and Maia behavior)
  - tests/test_uci.gd (additions for those two bridge seams only)
  - New: tests/test_analyser.gd
  - New: tests/fixtures/analysis/ (recorded Stockfish transcripts)
  - docs/spec.md (§15.3)

#### What to build

Given a saved game, run Stockfish over every position and write `user://analysis/<game file name>.json` (§15.3). Nothing in the UI calls it yet; the review (REV-005) and the queue (HIST-006) do. Until then a headless script analyses one PGN, which is also how fixtures get recorded.

#### Acceptance criteria

1. Positions are analysed backwards, last to first, with `MultiPV 2`; one `ucinewgame` per game and the hash kept for the whole game.
2. Each position is searched with `go nodes` at the budget (3 000 000, from `core/tunables.gd`). The search is stopped early once it has reached depth 12 and the last 3 completed depths have the same PV1 move and an expected-points change under 0.01 (EP as §15.4, cp clamped ±1000, mates ±1000). The rule is a pure, tested function.
3. Threads: "Background" sends `Threads 1`; "Max" sends logical cores − 1 (at least 1).
4. Every FEN is checked with `core/board.gd` before it is sent; an invalid position aborts that game's analysis with an error and nothing is sent, so Stockfish never sees it.
5. The JSON stores, per position: up to two PV lines (move list, `cp` or `mate`, depth) and the best move; a position with one legal move stores only PV1; a game-over position stores no PV and its terminal score (checkmate +1000 for the side that gave it, any draw 0). It also stores the engine version (from `id name`) and the node budget. The PGN is never touched.
6. A file whose engine version or budget differs from the current one reads as **stale**; a missing file reads as not analysed.
7. Progress is reported per position (a signal with done/total), so a caller can fill moves in as they land; analysis can be cancelled, and a cancelled game leaves no partial file.
8. `godot --headless -s scripts/analyse.gd -- <pgn>` analyses one game on Max and writes its JSON.

#### Verification

    Manual: run scripts/analyse.gd on a saved game; check the JSON and the time it took.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_analyser.gd`, with a fake bridge replaying fixture transcripts (CI has no Stockfish): positions are sent last to first; the convergence function stops at depth 12 with 3 stable depths and not before; an invalid FEN sends nothing; forced and terminal positions are stored as criterion 5; stale detection on version and budget (red: no analyser).
- `tests/test_uci.gd`, fake stdio: the handshake exposes `id name`; `stop_search()` sends stop only during an active search, and the subsequent bestmove reaches the callback and advances the queue.

## Comments

- 2026-10-30 Stage 2: the gate on commit `1a7332815c6fd9eff8f0d892d5f107cdc66c858a` reported 286 passed, 0 failed, exit 0; the recorded Stockfish 19 transcript covers MultiPV parsing. A two-ply synthetic PGN was analysed on Max, producing three positions with engine version and budget; its SHA-256 was unchanged. Manual verification on a real saved game remains pending.
- 2026-10-30 Written from spec §15.3. Speed figures in the spec are this machine's.
- 2026-10-30 REV-001 review handoff: criteria 2 and 5 here need an in-search `stop` command and the handshake's `id name`. The bridge's public `request_search()` queues commands until `bestmove` and forwards only search `info`/`bestmove`, so these two access paths remain to be designed for REV-002. Its current `engine/uci.gd` Primary-files entry only permits MultiPV parsing; resolve the seam/scope with the stage-1 proxy before adding bridge behavior. This is not a failure of REV-001's numbered criteria.

- 2026-10-30 Attempt 1 stopped to ask (its commits are on branch `recovery/asked/20261030-191713/REV-002`): REV-002 está bloqueado na branch `rev-002`, com o motivo registrado no commit `91f2d7a`. Nenhuma implementação foi iniciada. /  / O ticket precisa ampliar o escopo da ponte UCI para expor o `id name` recebido na inicialização e enviar `stop` durante uma busca ativa, inclusive no cancelamento. A [skill ticket-flow](C:/Users/bruno/.agents/skills/ticket-flow/SKILL.md) determina, quando o proxy falha: “set `Stage: blocked` with the question under `## Comments`, commit, stop.” /  / Você aprova ampliar `engine/uci.gd` e seus testes para essas duas interfaces, preservando o comportamento de Maia? Sua decisão permitiria retomar o ticket sem enviar o contexto ao proxy externo. /  / A revisão automática rejeitou a tentativa de executar o proxy com acesso de rede porque ela poderia enviar contexto do repositório a um serviço externo não especificado. A tentativa isolada anterior falhou com `ECONNREFUSED`.

- 2026-10-30 Proxy decided (opus-5.5 xhigh): Approve widening `engine/uci.gd` and `tests/test_uci.gd` by exactly two seams: the handshake's `id name`, and an in-search `stop`. — Criteria 2, 5 and 6 can't be met without them. Spec §15.3 says Stockfish runs "through the same bridge as Lc0", and the REV-001 handoff already left these two paths to REV-002. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-191716-REV-002-cdc3e7.json)
  > Decision: Approve widening `engine/uci.gd` and `tests/test_uci.gd` by exactly two seams: the handshake's `id name`, and an in-search `stop`. — Criteria 2, 5 and 6 can't be met without them. Spec §15.3 says Stockfish runs "through the same bridge as Lc0", and the REV-001 handoff already left these two paths to REV-002.
  > 
  > **Proposed bridge seams (drafts for stage 2):**
  > 
  > 1. **`id name`:** add a new public field, e.g. `engine_id: String`. In `poll()`, a line that starts with `id name ` sets it.
  >    - Keep it separate from `_engine_name`, which is the display name used in the "is missing" and "stopped" errors.
  >    - The handshake already waits for `uciok`, so the field is set before any search is sent.
  >    - Lc0 also sends `id name`, so storing it changes nothing for Maia.
  > 2. **In-search stop:** add a new method, e.g. `stop_search()`.
  >    - It writes `stop` straight to `_stdio`, skipping the queue, and only while `_awaiting == "bestmove"`. Otherwise it does nothing.
  >    - The search then ends normally: `bestmove` still reaches the callback and `_send()` moves on to the next queued step.
  >    - **Do not reuse or extend `stop()` (`engine/uci.gd:168`).** That method kills the process and Maia's shutdown depends on it.
  > 3. **Analyser side, not the bridge:**
  >    - Send `stop` at most once per search.
  >    - Request the next position only after handling the current search's `bestmove`; otherwise a late `stop` would cut the next search short.
  >    - Cancelling means: `stop_search()`, ignore the rest of that search's output, write no file. "No partial file" is the analyser's job; the bridge needs nothing more.
  > 4. **Rejected:** a subclass or separate Stockfish bridge, which goes against "same bridge as Lc0" in §15.3.
  > 
  > **Draft ticket text for REV-002:**
  > 
  > Replace the `engine/uci.gd` Primary-files entry and add one line under it:
  > 
  > ```
  >   - engine/uci.gd (MultiPV `info` parsing if it belongs there; a public field holding the handshake's `id name`; a `stop_search()` that sends `stop` only during an active search — `stop()` keeps killing the process; Maia's behaviour unchanged)
  >   - tests/test_uci.gd (additions for those two seams only; existing tests unchanged)
  > ```
  > 
  > Add to "Tests stage 2 writes":
  > 
  > ```
  > - `tests/test_uci.gd`, fake stdio as in `test_search_forwards_all_info_and_bestmove_to_the_request_callback`: `id name Stockfish 19` before `uciok` fills the bridge's engine id (red: dropped); `stop_search()` during a search writes `stop` and the later `bestmove` still reaches the callback and advances the queue; with no search it writes nothing (red: no method).
  > ```
  > 
  > **Next steps for the caller:**
  > 1. Apply both drafts to `53-REV-002-analysis-engine-and-files.md`.
  > 2. Record this answer under `## Comments`, set `Stage: to-implement` and commit.
  > 3. Resume stage 2 on `rev-002`. The recovery branch has only the blocking commit `91f2d7a`, so nothing needs to be brought over.
  > 
  > This doesn't need the owner: the change is internal and easy to undo, with no public API, merge, credential or data at stake.
  > 
  > I didn't run the gate, and no real Stockfish `id name` or `stop` exchange was tried. The fake-stdio tests only cover the bridge's own bookkeeping.

#### Resolution (2026-10-30)

Verdict: Approve

- Standards: 0 documented violations and 0 relevant heuristic findings. Spec: 0 confirmed findings against criteria 1-8. Independent Standards and Spec reviewers examined the full `7be9cac...18adc82` diff; the primary reviewer also read every changed file and the connected code. Coverage: total_files=9, reviewed_files=9, skipped_files=0, coverage_rate=100%. OCR excluded all nine files as `unsupported_ext`; all were reviewed manually with its default correctness, security, performance, maintainability and test-coverage rules.
- Criterion 1: passed. Positions are searched last to first with MultiPV 2; `new_game()` is called once, including terminal-only games, and no per-position hash reset is sent.
- Criterion 2: passed. The node budget and convergence thresholds live in `core/tunables.gd`. The pure function checks the last three completed PV1 depths, minimum depth 12, the same first move, EP range below 0.01, cp clamping and mate conversion. MultiPV completion waits for PV2 when two legal lines exist; `stop` is sent at most once per search.
- Criterion 3: passed. Background sends one thread; Max sends `max(1, logical cores - 1)`. The tests inspect both command configurations.
- Criterion 4: passed. The complete FEN array is validated before any engine command: Board parsing, king counts, pawn ranks, the previous mover's king safety and castling pieces. Invalid input rejects the analysis without starting a game or search.
- Criterion 5: passed. JSON records the game-ordered positions, per-line moves/score/depth, best move, handshake engine identity and budget. Forced positions retain PV1 only; terminal positions have no PV and use side-to-move scores (-1000 for checkmate, 0 for draws). The CLI passes the final draw result; analysis writes a separate JSON and does not write the PGN.
- Criterion 6: passed. Missing files read as not analysed; mismatched engine version or node budget reads as stale. Malformed JSON is also treated as stale.
- Criterion 7: passed. `position_ready(index, position)` and `progress(done, total)` publish completed positions. Cancellation stops the current search once, ignores its remaining output and writes no result; cancellation from a position callback prevents the next search.
- Criterion 8: passed. The headless CLI validates a single PGN, reconstructs its initial and subsequent positions, starts Stockfish on Max and writes `user://analysis/<PGN filename>.json`. Stage 2 recorded a successful two-ply synthetic Stockfish 19 run in 0.9 s with unchanged PGN SHA-256; this review did not repeat that run. A real saved-game timing/JSON check remains pending product acceptance.
- Examined callers and failure paths: full UCI handshake, queued callbacks, search stop and process cleanup; existing Maia setup and policy path; Board FEN/move/terminal handling; PGN replay; CLI startup/stopped-engine/write failures; analyser convergence, terminal/forced positions, missing/stale files, cancellation during a search and from progress callbacks. Future REV-005/HIST-006 UI/queue consumers do not exist in this change and were not exercised. No changed file was skipped.
- Scope decision: the recorded `Proxy decided (opus-5.5 xhigh): Approve widening engine/uci.gd and tests/test_uci.gd by exactly two seams` authorizes handshake `id name` and in-search `stop`. The receipt `C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-191716-REV-002-cdc3e7.json` matches REV-002 and that decision. The implementation preserves process-killing `stop()` and Maia behavior; no additional bridge seam was introduced.
- Test evidence: separate test/production commits were checked, including bridge identity/stop (`5c16ba3` / `cf8c186`), convergence (`d1710c3` / `82d6962`), lifecycle/storage (`c6c699a` / `a98355c`) and subsequent focused additions. Historical red executions were not replayed in this review. The recorded Stockfish transcript exercises the production MultiPV parser; the green gate includes the later cancellation regression test.
- Verification: the existing receipt and log SHA-256 were verified using `Assert-GateEvidence`, with 286 passed, 0 failed, 0 skips and exit 0 on `1a7332815c6fd9eff8f0d892d5f107cdc66c858a`. Only ticket metadata changed after that tested commit. The gate was reused, not rerun, because no production code changed during review, rebase or merge. Log: `C:\Users\bruno\AppData\Local\Temp\rev002-gate.log`.
- Integration: rebased onto `sweatshop/analysis/2026-10-30-1831` (already current), then merged without squash as `8a79621`. This resolution, `Stage: done` and the ledger entry are committed together on the session branch. No production behavior was authored during review.

Disclosure: decision | none | [Recorded proxy scope decision](#comments), receipt `C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-191716-REV-002-cdc3e7.json`: two internal bridge interfaces were approved to satisfy criteria 2, 5 and 6; their implementation and regression tests are included here.
Disclosure: pending | release | Run `scripts/analyse.gd` on a real saved game, inspect the complete JSON and elapsed time, and verify the PGN remains unchanged. The recorded synthetic run and fixture/headless checks do not establish that product acceptance. This remains part of [Bruno's release QA in spec section 15.1](../../../docs/spec.md#151-release-and-tickets), and does not prevent session integration.
