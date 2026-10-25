# OPEN-004: Review badges and repertoire check
Stage: to-implement
Blocked by: HIST-002, OPEN-003
Review: agent
Difficulty: normal

- Primary files:
  - New: bot/badges.gd
  - ui/review.tscn, ui/review.gd
  - ui/setup.gd (repertoire to check)
  - ui/main.gd (OPEN-004 composition only: pass catalog data, the check-my-moves setting, the selected repertoire and actual human side to review; snapshot the game's repertoire, load it in every opening mode when needed, and report load failures before starting a new game; preserve existing bot modes, history recognition and swapped-colour rematches)
  - core/settings.gd, ui/settings.tscn, ui/settings.gd ("Check my moves")
  - New: tests/test_badges.gd

#### What to build

The review marks where the game was in book and how your moves matched your repertoire (§6.4, §9.3). Nothing shows during the game.

#### Acceptance criteria

1. **Book**: every move whose position and move appear in the catalog (any line, checked or not) gets the badge, up to the first move that leaves the catalog; no Book badge after that.
2. "Check my moves against my repertoire" is a setting, off by default, usable in every opening mode with the repertoire picked on the setup screen. This setting controls Repertoire and Left repertoire only; Book remains enabled. Selecting a repertoire for checking in Free or Catalog does not change the chosen human colour or Maia's opening mode. Checking uses the actual human side, including rematches. A required saved-repertoire load failure reports an error and permits retry without using stale repertoire data.
3. With checking on and a selected repertoire loaded, compare each human move's position and move against all imported PGN paths, using position keys without move counters so transpositions count. Matching human moves receive Repertoire until the first unmatched human move, which receives the sole Left repertoire marker. Show the distinct expected continuations in SAN when present. When none exist, including after an opponent deviation or beyond a PGN leaf, show "No continuation in repertoire" instead of inventing an expected move. Opponent moves never receive repertoire badges. No repertoire badges appear after the human exit, even if play later returns to a known position.
4. Nothing about books or the repertoire is shown during the game.
5. Badges come from a pure function over the game and the books, tested on fixture games.

#### Verification

    Manual: play out of your repertoire on move 5; the review shows Repertoire to move 4 and Left repertoire with the expected move.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_badges.gd`: Book badges up to the exit, Repertoire / Left repertoire with the expected moves, and no repertoire badges with the setting off, while Book badges remain. Cover opponent deviation, PGN leaf, transposition, actual-colour/rematch, and real Setup/Main/Review wiring, including failed-load retry and no in-game badges. Red because `bot/badges.gd` does not exist.

## Comments

Proxy decided (gpt-6-astra high, fallback): Allow narrowly scoped Main composition and lifecycle wiring; keep Book independent of the repertoire toggle and mark only the first unmatched human move, with explicit no-continuation text where the PGN supplies none — Main owns setup/preferences/review composition, and OPEN-004 criteria 1–3 distinguish catalog recognition from human repertoire checking.

Disclosure: decision | none | OPEN-004 proxy scope and badge clarification: preserves opening modes, history and swapped-colour rematches; no migration or additional integration/release condition.

- Test harness correction: the first run could not infer the fixture board FEN type; declared it explicitly as String. This is a test-only correction; rerun must fail because the production badge module is missing.
- Repertoire fixture correction: the transposition fixture originally did not cover the intermediate black Nf6, so it required a valid earlier exit. Extend that fixture chapter through Nf6; Bg7 still requires matching the other chapter by position. The corrected tests are red against the Book-only implementation and green with repertoire evaluation.

- Stage 2 caller inspection: `ui/main.gd` is the caller of `review.present` and owns game start, rematches, settings and the setup catalog/repertoire. Existing review/export/time and setup colour/error behavior must remain intact. The new pure seam takes UCI moves and book paths; boundaries include empty games/books, unchecked lines, first exit and later transpositions back into the catalog. Tests live in `tests/test_badges.gd` as contracted.

> #### Stage 2 handoff (2026-10-25)
>
> - Implementation: pure `Badges.evaluate` indexes every catalog/repertoire position and returns one badge record per ply. Book stops permanently at the first catalog exit. Only actual human moves receive repertoire badges, ending at the sole human exit with distinct expected SAN moves or explicit no-continuation text.
> - Integration: the default-off boolean is persisted and editable; Setup supplies a repertoire in all modes while only My repertoire fixes the initial colour. Main snapshots the selected PGN before play, preserves Maia's mode/history catalog, uses the live check preference at review and rejects required load failures before starting the game. Rematches check the actual swapped human side.
> - Red/green cycles, with separate test-only and production-only commits:
>   - `6738d1f` against the missing module: 0 passed, 1 failed; `9ea630d`: 1 passed, 0 failed.
>   - Corrected fixture `48b0e44` against Book-only `9ea630d`: 1 passed, 3 failed; `7dfbf89`: 4 passed, 0 failed.
>   - `4ae7498`: 4 passed, 2 failed; `6247ef9`: 6 passed, 0 failed.
>   - `4d015e1`: 6 passed, 4 failed; `cf5a29a`: 10 passed, 0 failed.
>   - `0c2ef20`: 10 passed, 1 failed; `430edbe`: 11 passed, 0 failed.
> - Focused runs used an ignored copy of `tests/test_badges.gd` under `build/open004-tests`, because the existing runner selects directories. The full gate exercised the tracked test file. Local focused logs: `C:\Users\Lage\AppData\Local\Temp\OPEN-004-focused-{red,green}*.log`.
> - Gate on committed production `430edbe47b154659aa067f67d644fd098c109397`: `godot --headless -s tests/run.gd` → **229 passed, 0 failed**, exit 0. Existing review/time/export, repertoire/import, opening modes, history, settings and all other suites pass. The initial unprivileged full attempt was stopped after sandbox-denied user-storage writes; the evidenced run had the required storage access.
> - Visual verification: rendered Settings and Review at the 800×600 minimum size. All settings and action buttons remain inside the window. The badge column can truncate long text; the new wrapping exit detail line shows the complete expected moves without hovering and clears on rematch. Scripted production-review fixture `1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d4` against a PGN ending in `5. d3` displays Repertoire through move 4 and `5. White: Left repertoire — expected: d3`. Local captures: `build/open004-settings.png`, `build/open004-review-move5.png` (ignored verification artifacts).
> - Final scope/whitespace inspection passed; no generated artifacts are tracked. No known unresolved implementation defect. Independent stage-3 review remains next; no merge or push performed.
>
> Acceptance: passed | `tests/test_badges.gd` (11 pure/UI/session tests) and the rendered move-5 production-review fixture described above; no real-engine play-through claimed.
>
> Gate evidence: C:\Users\Lage\AppData\Local\Temp\p-chess-OPEN-004\gate.json
>
> #### Resolution (2026-10-25)
>
> Verdict: Approve
>
> Independent Standards and Spec sub-agents reviewed the full diff `2f5d1232f24e9f11ae9ae77b0e7a6e631d81659a...cc048be4bd88d63f51c0338cf811b8cb32a0a5a7`, all numbered criteria, the proxy amendment and docs/spec.md sections 6.4/9.3. This review authored no production or test changes. Rebase onto `sweatshop/core/2026-10-25-0159` was already up to date. Merge `c404dd9` preserves every implementation commit; its tree is identical to the independently reviewed ticket tree.
>
> ##### Standards
>
> 0 hard documented-standard violations; 0 actionable judgement-call smells. All thirteen commit stats preserve test/production separation: seven test-only commits (with permitted ticket metadata), five production-only commits and one metadata handoff. All source and test changes remain within Primary files. The pure evaluator, position index, repertoire snapshot and presentation are cohesive and follow the surrounding dictionary-based domain records. No unrequested refactor, added logging or concrete security/accessibility regression was found.
>
> ##### Spec
>
> 1. ✅ Book indexes all catalog entries regardless of picker checks. Position/move matches receive Book until the first exit; badges never resume afterward, including after returning to a known position. Checking off preserves Book.
> 2. ✅ The persisted boolean defaults to off and is editable in Settings. Setup supplies a repertoire in every mode; only My repertoire adopts its saved colour and supplies Maia's repertoire book. Main snapshots the loaded PGN, uses the live checking preference at review and the actual played colour on rematches, and reports required load failures before creating a new clock/game. Repair and retry do not use stale repertoire data. History retains the shared catalog.
> 3. ✅ Every imported path contributes position/move continuations using Board.position_key without counters. Only human moves receive repertoire badges, ending at the sole first human exit. Expected moves are distinct SAN; opponent deviations and PGN leaves display No continuation in repertoire. Tests cover transpositions, actual Black play and permanent exit. A wrapping detail label keeps expected moves readable outside the clipped badge column and clears for the next review.
> 4. ✅ The existing live SAN list has no book/repertoire annotations. Setup and Review stay hidden during play in all three modes; badges are presented only after the game ends.
> 5. ✅ Badges.evaluate reconstructs its own board and returns one record per ply without changing game/book data. Eleven production-bound pure, settings, Setup and real-Main/Review session tests cover the contracted behavior and failure paths.
>
> 0 missing/partial requirements, 0 scope-creep findings and 0 incorrect implementations. Examined the complete diff and all added tests; Main start/result/rematch callers; Setup mode, colour and load/retry paths; settings validation/persistence; Book/Repertoire parsing and indexing; Board position keys/SAN; Maia opening-mode selection; History catalog recognition; Review move times, export actions and reset state. Not experimentally examined in this review: a real-engine play-through, exported builds or physical storage failures. These changes introduce no new external integration boundary.
>
> Red/green evidence: inspected the retained focused logs and separate committed cycles. Missing module: **0 passed, 1 failed → 1 passed, 0 failed**; repertoire after fixture correction: **1 passed, 3 failed → 4 passed, 0 failed**; settings/setup: **4 passed, 2 failed → 6 passed, 0 failed**; Main/Review sessions: **6 passed, 4 failed → 10 passed, 0 failed**; readable exit details: **10 passed, 1 failed → 11 passed, 0 failed**. The typing and transposition fixture corrections are isolated test-only commits with explanations above. Tests call the production evaluator/scenes; the full gate uses the tracked test file rather than the ignored focused copy.
>
> Gate: Assert-GateEvidence validated the existing receipt against the reviewed HEAD and merge `c404dd9`: bound command `godot --headless -s tests/run.gd`, tested commit `430edbe47b154659aa067f67d644fd098c109397`, **229 passed, 0 failed**, exit 0. SHA-256 `5788008C4BCA6931A77B820ECBE4212C70E1E0F0E4318E98402F3017486D5307` and the exit marker match; the tested commit exists. All eleven new tests pass in the full log; no ERROR/SCRIPT ERROR is present. Only permitted tracker metadata differs from the tested code, so the green gate is reused. `git diff --check` passes.
>
> Visual acceptance: independently inspected the existing Settings and move-5 Review captures at 800×600 and their production-scene fixture. Controls/actions fit; Repertoire appears through move 4 and the readable detail says `5. White: Left repertoire — expected: d3`. The long badge text clips within its table cell, with the complete explanation visible below it. No real-engine play-through is claimed.
>
> Proxy review: the existing Proxy decided (gpt-6-astra high, fallback) amendment is satisfied by the narrowly scoped Main composition, catalog badges independent of checking, the sole human exit and explicit no-continuation text. Existing bot modes, history ownership and swapped-colour rematches are preserved. No new proxy decision or contract amendment was made.
>
> Acceptance: passed | Eleven production-bound badge tests, the validated 229-test gate, independent Standards/Spec review and the rendered move-5 fixture above satisfy this ticket's acceptance scope.
> Disclosure: decision | none | Existing OPEN-004 proxy scope/badge clarification is implemented and independently approved; no migration or additional integration/release condition. No unresolved finding remains.

#### Session review reopen (2026-10-25, PR #10)

Verdict: Reopen — enabling repertoire checking while the catalog loads skips the required repertoire-load validation, so the game starts with checking on, an empty repertoire snapshot and no error.

Source: independent review of session PR #10, head 6fbac3e (gpt-6.1-sol xhigh, relayed by the supervising session): "do not merge", two blocking findings. Review gate 235/0 with live Lc0, no skips.

Finding 2 (blocking), `ui/main.gd:183-186` (`_start`, from `cf5a29a`) with OPEN-002's catalog `await`: whether the repertoire load error blocks the start is decided before `await ensure_catalog()`, from `check_repertoire` at that moment. Reproduction (real Main and the Settings controls): Free mode, a corrupt saved repertoire selected, checking off; press Start, then turn checking on in Settings while the catalog loads. Main creates the clock and requests Maia's move with checking on, an empty repertoire snapshot and no error, and the review later omits the repertoire badges. Criterion 2 requires a required saved-repertoire load failure to report an error and permit retry without using stale repertoire data; criterion 3 requires the badges when checking is on.

Scope for this ticket: after the catalog `await`, re-evaluate whether the repertoire is required (My repertoire mode, or checking on now) and reject a failed load before the game starts, showing the error on the setup screen as before; keep the snapshot rule for checking turned on later during play.

Regression to write first (own commit, red), in `tests/test_badges.gd` (real Main, as the existing session tests): Free mode, corrupt saved repertoire, checking off; Start, enable checking through the Settings control during the catalog load; assert the game does not start, no Maia request or clock is created, and the setup shows the load error.

Next action: stage 2.
