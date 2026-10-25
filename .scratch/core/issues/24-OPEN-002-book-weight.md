# OPEN-002: Book weight in Catalog mode
Stage: implementing
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

## Comments

Proxy decided (gpt-6-astra high, fallback): Add narrowly scoped Main lifecycle wiring and scene-backed tests in test_book.gd; clarify criterion 7 to allow positional re-entry — existing criteria require Main's setup/settings/history integration, and position-indexed transpositions must remain valid after leaving a checked line.

Disclosure: decision | none | OPEN-002 Comments, proxy scope and criterion-7 amendment: completes existing app integration and clarifies positional matching; no separate integration or release dependency.

Proxy decided (gpt-6-astra high, fallback): Add opening_picker.gd solely for a shared public asynchronous catalog-readiness entry point used by Main and present() — the picker owns the existing worker, and sharing its lifecycle avoids private-state access, duplicate parsing and concurrent mutation.

Disclosure: decision | none | OPEN-002 Comments, shared catalog-loader amendment: preserves one catalog and responsive loading while completing existing criteria; no separate integration or release dependency.

Stage-2 caller inspection: Book's catalog/search/selection APIs feed opening_picker and setup; retain their entry format and checks. Maia.begin_game is called by Main and think's implicit new-game path; existing one-argument calls must retain Free behavior and invalidate stale policies. Main owns preferences, rematches, clock creation and the once-only history guard. History.save's explicit Opening argument and existing stats callers remain supported. Boundary coverage includes empty selections, unchecked lines, no matching continuation, re-entry with a larger game ply, completed lines, no known opening, stale replies, failed storage and catalog readiness before a game starts.
