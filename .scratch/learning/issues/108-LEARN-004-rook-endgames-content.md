# LEARN-004: Rook endgames content
Stage: to-implement
Blocked by: RES-001, LEARN-002
Review: human
Difficulty: normal

- Primary files:
  - data/course/rook-endgames.json
  - data/course/course.json (the stage name)
  - tests/test_course.gd (only a data-shape check over the real unit file)

#### What to build

Claude drafts the unit's content and Bruno tunes it (spec Further Notes). The unit file gets the complete theory pointer, 12 practice positions, about 18 test positions, the 4 play-outs and the test's 2 play-out positions (spec §L1), mixing winning and holding sides around the Lucena and Philidor ideas. Positions come from setups built by hand and from the Lichess database (CC0, ADR 0002), as RES-001 recommends.

#### Acceptance criteria

1. The practice pool has 12 positions and the test pool 15–20, with no FEN in both; each position has a legal FEN with only kings, rooks and one pawn, a side that is the side to move in the FEN (your line starts with your move, spec §L6), a goal (win or hold) and a line length of 2–4 of your moves.
2. Both pools mix sides and goals: at least a third of each pool is holding positions, and each pool has positions with you as White and as Black.
3. Every position's goal matches the tablebase result for the side you play (checked with the tablebase as RES-001 describes, the check's output pasted under Comments).
4. There are 4 play-outs (2 convert, 2 hold) and 2 test play-outs (1 convert, 1 hold), none also used as a solving position.
5. The theory pointer has a one-line goal, 3–5 search terms and 1–2 books, each with its chapter or section named; `[chapter]` placeholders are gone.
6. The stage has a name in `course.json` (Bruno's call; the design's `[Stage name]` is gone).
7. A test loads the real unit file through the course module and checks the shape rules in criteria 1, 2 and 4.

#### Verification

    Manual: Bruno plays through a few positions on the solving board once it exists, and tunes line lengths.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: the real `rook-endgames.json` has 12 practice positions, a 15–20 test pool, no shared FENs, the side and goal mix, and 4 + 2 play-outs (red: the file has only the two seed positions).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L1. `Review: human` because Bruno tunes the content.

- 2026-11-07 RES-001 review follow-up: the ten random KRPKR positions per Maia net are research samples, not validated course content. Their result-preservation ratios cannot establish whether holds are too easy or converts too hard. Bruno's content tuning and actual human play-outs remain pending release acceptance here and in LEARN-007; see `docs/research/tablebase.md`, Maia experiment, and RES-001's dated Resolution.
