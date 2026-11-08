# REV-011: The from-your-game marker in Review
Stage: to-review
Blocked by: LEARN-006, LEARN-009
Review: agent
Difficulty: normal
Gate evidence: /run/media/lage/New Volume/Scratch/REV-011/gate.json

- Primary files:
  - data/course/rook-endgames.json (default line length for positions from games)
  - ui/review.gd (`present` move-list rows, `_fit_exit_rows`; the marker row beside the "Left repertoire" one)
  - ui/main.gd (the marker's link opens the unit page)
  - core/course.gd (adding a from-your-game position, once per FEN)
  - New: core/own_game_scan.gd (finding your result-changing moves in rook and pawn against rook, over the probe)
  - New: tests/test_own_game_scan.gd
  - tests/test_review.gd
  - tests/test_course.gd

#### What to build

When Review shows a game that reached rook and pawn against rook, each of your moves in that material that changed the result for your side gets a marker row under it, in the "Left repertoire" pattern but green, linking to the unit (spec §L10, design `ReviewMarker.dc.html`). The position before the move joins the unit as "From your game", and Continue offers it (LEARN-009).

#### Acceptance criteria

1. The scan looks only at your moves played from positions with exactly king, rook and one pawn against king and rook (either colour, either side with the pawn).
2. For each such move it asks the probe for the result for your side before and after; a different result marks the move.
3. Each marked move gets a full-width row under its move-list row: "Rook and pawn against rook · this move turned <before> into <after>" and "Practise in Rook endgames", green, not selectable as a move, sized like the "Left repertoire" rows.
4. Clicking the row opens the unit page.
5. The position before each marked move is added to the unit's from-your-game positions with your side, the goal from the result before the move (win or hold) and the unit's default line length; the same FEN is never added twice.
6. Games that never reach that material are not probed, and their Review is unchanged.
7. When the probe is unavailable, Review shows no markers and adds nothing, with no error dialog.

#### Verification

    Manual: review a saved game that lost a drawn rook ending; follow the marker to the unit.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_own_game_scan.gd`: with a fake probe over a fixture PGN reaching the material: a result-changing move is found; a kept-result move isn't; positions outside the material aren't probed (red: no scan).
- `tests/test_review.gd`: presenting that game with a fake probe adds one marker row under the move; clicking it emits the unit request (red: no row).
- `tests/test_course.gd`: adding the same FEN twice keeps one from-your-game position (red: no function).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L10.

- 2026-11-08 Attempt 1 stopped to ask (its commits are on branch `recovery/asked/20261108-062806/REV-011`): O REV-011 está **bloqueado** na branch `ticket/REV-011`. Preservei um teste para impedir posições duplicadas por FEN, mas a execução foi interrompida antes de verificar a falha esperada; a implementação ainda não começou. /  / Qual deve ser o comprimento padrão das linhas para posições “From your game”? A unidade atual não define um padrão; suas posições usam 2, 3 e 4 movimentos. Minha sugestão é definir **3 movimentos** explicitamente nos dados da unidade. /  / O proxy do fluxo falhou sem retornar uma decisão. A [skill ticket-flow](/home/lage/.agents/skills/ticket-flow/SKILL.md) determina que, nessa situação, se registre `Stage: blocked` e, em sessão acompanhada, se apresente a falha ao usuário. A pergunta e o trabalho preservado estão no [ticket REV-011](/home/lage/Projects/P-Chess/.artifacts-build/lanes/learning/.scratch/learning/issues/114-REV-011-from-your-game-marker.md).

- 2026-11-08 Proxy decided (opus-5.5 xhigh): add `"default_line_length": 3` to the unit file `data/course/rook-endgames.json` and use it for every "From your game" position. Three is in the middle of the unit's 2–4 range, and the design for a "From your game" position (`docs/design/learning/SolvingEntry.dc.html`, the `fromGame` chip) shows "Enter 3 of your moves". (receipt /tmp/sweatshop-proxy/20261108-062810-REV-011-ebb3e4.json)
  > Decision: add `"default_line_length": 3` to the unit file `data/course/rook-endgames.json` and use it for every "From your game" position. Three is in the middle of the unit's 2–4 range, and the design for a "From your game" position (`docs/design/learning/SolvingEntry.dc.html`, the `fromGame` chip) shows "Enter 3 of your moves".
  > 
  > **Evidence**
  > - Spec §L10 and criterion 5 both say "the unit's default line length". §L1 lists what a unit file holds but has no such field, so the spec never defined it. This decision fills that gap.
  > - The unit's positions use 2, 3 and 4 moves, and `tests/test_course.gd:453` only allows lengths of 2–4. Three fits that range.
  > - The test checking the unit's data (`tests/test_course.gd:425`) only looks at positions, not at keys on the unit itself, so adding a new key there breaks nothing.
  > 
  > **Drafts for the caller to apply** (contract edits are yours to make)
  > - **Spec §L1:** after "the line length in your moves, and its pool (practice or test);" add: "the default line length for from-your-game positions (`default_line_length`, 3 for rook endgames);".
  > - **REV-011 Primary files:** add `data/course/rook-endgames.json` (the new `default_line_length` key). Criterion 5 stays as written.
  > - **Implementation:** Review or the scan builds the position with `line_length = unit.default_line_length` and passes it to `course.add_from_game`. The test kept on `recovery/asked/20261108-062806/REV-011` (commit `ff03584`) already passes a full position with `line_length: 3`, so it needs no change. Any course fixture that reaches `add_from_game` through the unit should set the key too.
  > 
  > **Impact:** one new key in one data file and one sentence in the spec. Nothing in other lanes reads it, saved progress is unaffected, and no public API changes.
  > 
  > **Next:** record this under REV-011 `## Comments`, apply the two drafts, set `Stage: 2`, and rerun stage 2 starting from the kept commit `ff03584`. That run still has to confirm the expected red failure, which attempt 1 never checked.
  > 
  > I did not run the gate or check the test in `ff03584`.


## Resolution

Review scans relevant moves with the tablebase, shows a linked green marker and saves each starting FEN for Continue. The unit sets a default of three moves. The headless gate `godot --headless -s tests/run.gd` passed with 674 tests and 0 failures. The saved-game visual walkthrough remains for manual verification.

### Criteria check

Fresh-context subagent checked each criterion and rechecked the added coverage.

- ✅ 1: `core/own_game_scan.gd:11` filters side and exact material; `tests/test_own_game_scan.gd:7`, `:49`, `:100` cover player colours and adjacent material.
- ✅ 2: `core/own_game_scan.gd:30` compares results from the player's perspective; `tests/test_own_game_scan.gd:7`, `:49`, `:78` cover changed and kept results and a PGN reaching the material.
- ✅ 3: `ui/review.gd:1437` adds a full-width, green, nonselectable marker sized by `ui/review.gd:448`; `tests/test_review.gd:2350` checks the text, placement and selection. Colour, multiple markers and resize remain visual verification gaps.
- ✅ 4: `ui/review.gd:347` emits the request and `ui/main.gd:290` opens the unit; `tests/test_review.gd:2350` and `:2395` check both links.
- ✅ 5: `ui/review.gd:1449`, `core/course.gd:181`, `data/course/rook-endgames.json:5` save the position, deduplicate the FEN and set the default; `tests/test_course.gd:539`, `tests/test_review.gd:2350`, `:2447` cover persistence, goals and Continue.
- ✅ 6: `core/own_game_scan.gd:11` returns without probing nonmatching material; `tests/test_own_game_scan.gd:32`, `:100` cover no probes. A direct visual comparison of Review without matching material remains manual.
- ✅ 7: `core/own_game_scan.gd:30` discards results on probe failure; `tests/test_review.gd:2428` checks no marker, saved position or error dialog.

The initial marker fixture needed explicit Array typing and one clock per move; these harness corrections are in test-only commits. A mutation of material filtering and result inversion failed the scan tests as expected. The stale-review test exposed a freed row capture, fixed before the gate.
