# OPEN-002: Book weight in Catalog mode
Stage: to-review
Blocked by: BOT-003, HIST-001, OPEN-001
Review: agent
Difficulty: hard

- Primary files:
  - bot/book.gd
  - bot/maia_player.gd
  - core/history.gd (practice counts, Opening header)
  - core/settings.gd, ui/settings.tscn, ui/settings.gd (book intensity)
  - New: tests/test_book.gd
  - ui/main.gd (OPEN-002 lifecycle wiring only: supply opening mode, saved selection and Maia's side at game start/rematch; connect the shared catalog and practice counts; apply book intensity; record the target once at game end and supply the deepest reached catalog Opening to history)
  - ui/opening_picker.gd (shared asynchronous catalog readiness only: expose a public ensure_catalog entry point, reuse it from present(), share the existing worker, join it once after completion, and preserve picker selection/display behavior)
  - tests/test_history.gd, tests/test_premove.gd, tests/test_review.gd, tests/test_session.gd (existing _session helpers only: inject a tiny preloaded catalog before Main enters the scene tree; preserve all existing behavior assertions)

#### What to build

In Catalog mode Maia leans toward the checked lines and drifts off them as the game deepens (§6.2, §6.3). The weights feed the move picker before its cut (BOT-003).

#### Acceptance criteria

1. The book is indexed by position key, so a transposition into a checked line counts.
2. For each legal move `m` that keeps the game on a checked line, `w(m) = 1 + (B − 1) · f(d)`, where `d` is the game's current ply number; every other move has `w = 1`.
3. `f(d) = 1` for `d ≤ 6`, falls linearly to 0 at `d = 16` (`f(11) = 0.5`), and is 0 after.
4. `B = B_target` when `m` follows the target line, else `B_other`. Book intensity weak / medium / strong gives `(B_target, B_other)` = (5, 2), (20, 5), (100, 15); default medium, stored as a setting.
5. The target line is picked at game start: among the checked lines (in My repertoire mode, the lines for Maia's side), the one with the lowest practice count; ties are broken by the RNG.
6. At game end the target line's practice count goes up by one; counts persist under `user://`.
7. At a position with no matching continuation in any checked line, every weight is 1. Matching is evaluated from the current position on each Maia turn: transposing back into a checked line restores the applicable weights, using the current game's ply for the fade. Leaving the book does not permanently disable it.
8. A saved game's `Opening` header names the deepest catalog line whose position the game reached (in every mode).
9. Integration with the picker: a line move that Maia rates at 0.5% is sampled at least once in 1,000 seeded games' first Maia move under strong intensity, and never under Free mode.
10. The real Main lifecycle connects the setup's Catalog/Free mode and saved selection to Maia, including rematches and Maia's actual side. Book-intensity changes apply to subsequent move requests. Each completed game records its selected target at most once, and saved games in every mode receive the deepest reached catalog Opening when known. Catalog availability must not depend on opening the catalog picker during this app session; shared catalog loading must preserve UI responsiveness and avoid concurrent access while its loader is mutating it. Main and the picker use the same catalog-loading operation. Starting a game with an unloaded catalog displays loading status and waits responsively before creating the game clock or requesting Maia's move. Readiness is published only after the worker has completed and been joined; already loaded catalogs complete immediately. Loader startup failure reports an error and leaves the app able to retry without starting a game. Loading for Main must not open the picker or implicitly apply the picker's remembered selection; Catalog loads the selection named in the current game's setup settings.

#### Verification

    Manual: check one line, play five games as white; Maia follows it early and leaves it later.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_book.gd`: weights at plies 4, 11 and 18; a transposition; target-line choice with counts and a seeded tie; weights after leaving the book; the Opening header name; the picker integration of criterion 9. Red because the book weight does not exist.
- `tests/test_book.gd` also exercises the real Main scene with a fake engine and isolated settings, selections and history storage: Catalog/Free setup-to-Maia wiring, saved selection versus residual checks, rematch target choice, live intensity routing, one practice increment despite repeated terminal callbacks, persisted counts, and Opening headers in Catalog and Free. Include a catalog-not-yet-loaded lifecycle case and leave/re-enter position matching. These tests call production code; they do not duplicate its weighting or lifecycle logic.
- `tests/test_book.gd`: exercise the public catalog-readiness lifecycle, including an already loaded catalog, a cold start without opening the picker, joining an existing load without starting another, and startup failure with no clock or Maia request. Verify Main remains responsive while waiting and starts only after readiness. Keep storage isolated and external engine behavior fake.
- Existing scene-test helpers in test_history.gd, test_premove.gd, test_review.gd and test_session.gd receive a tiny catalog through the real Book.load_tsv API before Main enters the tree. This keeps their established already-loaded, synchronous setup while cold loading remains covered in test_book.gd. No production test-detection shortcut, weakened assertion or full-catalog parse per fixture.

## Comments

Proxy decided (gpt-6-astra high, fallback): Add narrowly scoped Main lifecycle wiring and scene-backed tests in test_book.gd; clarify criterion 7 to allow positional re-entry — existing criteria require Main's setup/settings/history integration, and position-indexed transpositions must remain valid after leaving a checked line.

Disclosure: decision | none | OPEN-002 Comments, proxy scope and criterion-7 amendment: completes existing app integration and clarifies positional matching; no separate integration or release dependency.

Proxy decided (gpt-6-astra high, fallback): Add opening_picker.gd solely for a shared public asynchronous catalog-readiness entry point used by Main and present() — the picker owns the existing worker, and sharing its lifecycle avoids private-state access, duplicate parsing and concurrent mutation.

Disclosure: decision | none | OPEN-002 Comments, shared catalog-loader amendment: preserves one catalog and responsive loading while completing existing criteria; no separate integration or release dependency.

Stage-2 caller inspection: Book's catalog/search/selection APIs feed opening_picker and setup; retain their entry format and checks. Maia.begin_game is called by Main and think's implicit new-game path; existing one-argument calls must retain Free behavior and invalidate stale policies. Main owns preferences, rematches, clock creation and the once-only history guard. History.save's explicit Opening argument and existing stats callers remain supported. Boundary coverage includes empty selections, unchecked lines, no matching continuation, re-entry with a larger game ply, completed lines, no known opening, stale replies, failed storage and catalog readiness before a game starts.

Proxy decided (gpt-6-astra high, fallback): Allow tiny preloaded-catalog injection in the existing _session helpers of test_history.gd, test_premove.gd, test_review.gd and test_session.gd, preserving their assertions — asynchronous cold loading otherwise invalidates their synchronous setup and repeats expensive catalog parsing; test_book.gd retains dedicated cold-load coverage.

Disclosure: decision | none | OPEN-002 Comments, existing scene-fixture amendment: test setup only, with unchanged behavior assertions and no separate integration or release dependency.

#### Stage 2 handoff (2026-10-25)

- Branch: `OPEN-002-book-weight`, based on `sweatshop/core/2026-10-25-0159` at `6550088`. All changes remain within the amended Primary files. Existing scene-test assertions are unchanged; their four `_session` helpers only preload a tiny catalog through `Book.load_tsv`. Settings rows are built dynamically, so `ui/settings.tscn` needed no edit.
- Position-indexed continuations snapshot the checked lines at game start. `Book.begin_game(counts, rng, side := "") -> String` chooses the least-practiced eligible target; ties use the supplied RNG. Imported lines may supply `colour`; catalog lines remain available to either side. `weights(board, ply, intensity := "medium")` returns one weight per legal move, applies the specified target/other intensities and game-ply fade, and permits positional re-entry. Unchecked lines and unmatched continuations retain weight 1.
- `MaiaPlayer.book`, `book_intensity` and `target_id` connect the book to policy sampling. `begin_game(game, mode := "Free", counts := {}, side := "")` preserves existing one-argument Free calls. Each think request snapshots its book weights before the existing picker cut/temperature; stale FIFO replies still drop. The `book_intensity` setting defaults to medium, validates weak/medium/strong, persists and applies live through the settings row.
- `History.practice_counts()` reads the `practice` section of the existing `stats.cfg`. `save` accepts an optional fifth `target_id`; Main supplies it through its existing once-only terminal guard. `History.book` recognizes the deepest catalog endpoint actually reached, including transpositions and games in Free, while preserving the explicit Opening override. No new storage format or migration is required.
- `OpeningPicker.ensure_catalog() -> String` asynchronously shares the existing worker between Main and the picker, publishes readiness only after joining it, and completes immediately for loaded catalogs. Main waits with a loading status and board input disabled before creating a clock or requesting a move. It loads the saved selection named in the current setup, hides any old popup, and reports loader/selection errors with a usable retry. No remembered picker selection is implicitly applied by Main.
- Red/green cycles (all logs under `C:\Users\Lage\AppData\Local\Temp\`): `7da803c` -> `683dc5a`, weights **0 passed, 1 failed -> 1 passed, 0 failed** (`OPEN-002-weights-{red,green}.log`); `ff082b9` + harness correction `6e0107d` -> `cf0419f`, history/recognition **3 passed, 2 failed -> 5 passed, 0 failed** (`OPEN-002-history-{red,green}.log`); `9e64a4c` -> `5e82824`, Maia/settings **5 passed, 2 failed -> 7 passed, 0 failed** (`OPEN-002-picker-{red,green}.log`); `9baecb0` -> `d27e22f`, Main/readiness **7 passed, 3 failed -> 10 passed, 0 failed** (`OPEN-002-lifecycle-{red,green}.log`); `c9d7b02` -> `267086f`, loading-input regression **10 passed, 1 failed -> final gate 210 passed, 0 failed** (`OPEN-002-loading-input-red.log` and gate log). Each production commit contains no test edits. The initial history test failed to parse because GDScript statically rejected the not-yet-existing fifth save argument; the separate harness-only correction uses dynamic dispatch so the corrected red run fails on missing practice/recognition APIs, with existing behavior green. It also compares the non-exact floating-point ply-8 result approximately.
- Final bound gate on committed clean `267086f2daf6e413439bc6e5794a574350caf333`: `godot --headless -s tests/run.gd` through `gate-evidence.ps1` -> **210 passed, 0 failed**, exit 0, no SKIP lines. This includes all 11 new book tests, 1,000 seeded first moves per mode, existing rules/perft/UI/history tests, and live Lc0 (30 legal plies; median policy latency 16.8 ms). Expected malformed-time-table diagnostics remain from existing tests. Log: `C:\Users\Lage\AppData\Local\Temp\OPEN-002-green-gate.log`; SHA-256 `8369E96AEFCEFD39421031F7C100C6D19EA18443D7C7085E99B9A173E6CE221E`.
- Scripted product acceptance exercised the actual Main/picker scenes, real checkbox/save controls, full catalog and real Lc0 Maia-1500, with isolated preferences/selections/history. Catalog: **3,865 entries, 0 errors, 14,300 ms**, with **2,034 real event-loop frames** processed while loading. Checked one Bernstein Variation, saved the selection, then played five games as White, each 24 plies. Early line moves: **13/15**; late Maia turns (ply >= 16) with every weight 1: **20**. Exactly five PGNs parse with Opening headers, and the selected target's persisted practice count is exactly five despite repeated terminal callbacks. Artificial think delays were disabled for this acceptance run; real policies and normal clock/move/history routing remained enabled. Log: `C:\Users\Lage\AppData\Local\Temp\OPEN-002-acceptance.log`; script: `C:\Users\Lage\AppData\Local\Temp\OPEN-002-acceptance.gd`; saved evidence: `C:\Users\Lage\AppData\Roaming\Godot\app_userdata\[P] Chess\OPEN-002-acceptance-579342`. **0 acceptance failures**. This was headless automation; visual layout and hands-on play were not assessed.
- Final diff inspection and `git diff --check` passed. No generated files are tracked. Independent stage-3 review and integration remain for the next session; no review verdict or merge is claimed here.

Acceptance: passed | C:\Users\Lage\AppData\Local\Temp\OPEN-002-acceptance.log — five scripted real-engine games through the production scenes, with responsive catalog loading, early book preference, complete late fade, five durable target counts and five named PGNs; headless acceptance, without visual assessment.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\OPEN-002-green-gate.json
