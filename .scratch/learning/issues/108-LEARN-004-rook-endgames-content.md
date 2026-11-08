# LEARN-004: Rook endgames content
Stage: to-review
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

- Proxy decided (opus-5.5 xhigh): Name the stage "Endgame foundations" and go ahead with the draft content. Bruno can change the name or the content when he does the `Review: human` review — it's one string in a data file, so it's cheap to change. (receipt /tmp/sweatshop-proxy/20261108-005906-LEARN-004-0a1258.json)

- 2026-11-07 Written from `.scratch/learning/spec.md` §L1. `Review: human` because Bruno tunes the content.

- 2026-11-07 RES-001 review follow-up: the ten random KRPKR positions per Maia net are research samples, not validated course content. Their result-preservation ratios cannot establish whether holds are too easy or converts too hard. Bruno's content tuning and actual human play-outs remain pending release acceptance here and in LEARN-007; see `docs/research/tablebase.md`, Maia experiment, and RES-001's dated Resolution.

#### Stage 2 evidence (2026-11-08)

- Independent read-only criteria check (including rechecks after corrections):
  - 1 ✅ `data/course/rook-endgames.json:20` supplies 12 practice and 18 test positions. `tests/test_course.gd:203` loads the real unit through `Course.units()`, checks material, playable FEN state, side, 2–4 integer moves and distinct position keys; python-chess independently validates all FENs below.
  - 2 ✅ `data/course/rook-endgames.json:20` mixes both colors (practice 6 white/6 black; test 8 white/10 black) and goals (5/12 and 7/18 holds), checked through the course module by `tests/test_course.gd:253`.
  - 3 ✅ The complete independent Syzygy output for every solving and play-out FEN is pasted below; each side-to-move win/convert is +2 and each hold is 0. This check is external to the Godot test suite.
  - 4 ✅ `data/course/rook-endgames.json:292` and `:322` have 2 convert + 2 hold and 1 convert + 1 hold, respectively; `tests/test_course.gd:261` verifies counts, side-to-move and disjoint position keys.
  - 5 ✅ `data/course/rook-endgames.json:5` has a one-line goal, four terms and one book with named Lucena and Philidor sections. The Library of Congress table of contents confirms those section names: https://catdir.loc.gov/catdir/toc/ecip076/2006037884.html. `tests/test_course_screens.gd:46` checks that the populated reference section appears; content text was checked manually.
  - 6 ✅ `data/course/course.json:4` names the stage “Endgame foundations”, and `tests/test_course_screens.gd:29` checks it appears on the map. The proxy decision above selects a draft name for Bruno to confirm or change.
  - 7 ✅ `tests/test_course.gd:203` exercises the real file through the production course module, including the required shape, distribution and play-out assertions. The independent recheck confirmed the supplied FENs against python-chess.
- Red/green: `94309ec` failed against the seed file on the missing 12/15–20 pools and 4+2 play-outs. The added screen expectations failed on the provisional name and empty book list at `de06a51`, then passed against the populated data. Godot JSON numbers decode as floats; `3515871` corrected that test harness and retained a red check against the seed. The impossible castling-rights mutation failed the expanded legality assertion (`4f2e243`); the focused real-data test passed after restoration. The existing empty-books assertion was retained with a unit copy in `f573557`; forcing the read card visible made it fail, and restoring production made it pass. No grading or human difficulty claim is derived from these shape checks.
- Source and verification: the Lichess puzzle export is CC0 under ADR 0002; the listed puzzle URL identifies each selected example, after applying the export's opponent move to its FEN. Downloaded 2026-11-08, compressed file SHA-256 `7b0d235fa40cfd7fdb7df1fec56a96b3b6ee1496b32ed2eb05be90d0ebf94253`. Additional setups are identified individually as hand-built, generated, adapted from the RES-001 sample, or from the cited canonical reference. The python-chess 1.11.2 verifier `/run/media/lage/New Volume/Scratch/LEARN-004/verify.py` checks `Board.is_valid()`, no repeated board/turn, side, five-piece material, Syzygy WDL and DTZ against the local files from `docs/research/tablebase.md`; it also checks the DTZ against the remaining 50-move clock. WDL +2 is an unconditional win for the listed side to move, 0 a draw; DTZ is plies to zeroing. Raw output:

```text
practice-01 | 4K3/2k5/2r5/4p3/8/8/R7/8 b - - 0 1 | win | WDL +2 | DTZ +11
practice-02 | 8/8/8/8/4pk2/R7/7r/4K3 w - - 0 1 | hold | WDL +0 | DTZ +0
practice-03 | 8/8/8/8/4p3/7R/3k2K1/r7 w - - 2 60 | hold | WDL +0 | DTZ +0
practice-04 | 4K1k1/4P3/8/8/8/8/7r/R7 w - - 0 1 | win | WDL +2 | DTZ +9
practice-05 | 8/7r/5R2/4kPK1/8/8/8/8 b - - 4 63 | hold | WDL +0 | DTZ +0
practice-06 | 8/6r1/4P3/8/k2K4/5R2/8/8 w - - 0 1 | win | WDL +2 | DTZ +7
practice-07 | 8/3k4/6K1/2p4r/4R3/8/8/8 b - - 0 1 | win | WDL +2 | DTZ +9
practice-08 | 8/2P5/1K1k4/1R6/8/8/8/3r4 b - - 0 79 | hold | WDL +0 | DTZ +0
practice-09 | 8/8/2P5/1k6/8/r7/2RK4/8 b - - 4 51 | hold | WDL +0 | DTZ +0
practice-10 | 1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1 | win | WDL +2 | DTZ +15
practice-11 | 8/8/8/2r1P2R/8/6K1/8/1k6 w - - 0 1 | win | WDL +2 | DTZ +9
practice-12 | 1k2K3/8/8/8/7r/p7/5R2/8 b - - 0 1 | win | WDL +2 | DTZ +13
test-01 | 8/R4K2/8/4k3/4rp2/8/8/8 w - - 0 64 | hold | WDL +0 | DTZ +0
test-02 | 8/4R3/8/1r6/1P6/8/3K3k/8 w - - 0 1 | win | WDL +2 | DTZ +9
test-03 | 8/4r3/2P5/8/1K4R1/8/8/5k2 w - - 0 1 | win | WDL +2 | DTZ +7
test-04 | 1R6/8/8/8/8/6K1/6p1/5rk1 w - - 8 73 | hold | WDL +0 | DTZ +0
test-05 | 1R6/8/8/8/3K1k2/4rp2/8/8 b - - 0 1 | win | WDL +2 | DTZ +11
test-06 | 8/8/7k/8/2K2p2/6r1/3R4/8 b - - 0 1 | win | WDL +2 | DTZ +13
test-07 | 4k3/1R6/4K3/5P2/8/8/8/r7 b - - 6 49 | hold | WDL +0 | DTZ +0
test-08 | 8/8/2k5/8/5K2/3R4/2p5/2r5 w - - 0 61 | hold | WDL +0 | DTZ +0
test-09 | 4k3/8/5KP1/5R2/8/8/8/7r b - - 0 95 | hold | WDL +0 | DTZ +0
test-10 | 3r4/8/8/2P5/K7/8/3k4/R7 w - - 0 1 | win | WDL +2 | DTZ +7
test-11 | 8/8/2r5/8/3k4/6K1/3p4/3R4 b - - 0 1 | win | WDL +2 | DTZ +7
test-12 | 4R3/8/8/8/K2k4/4p1r1/8/8 b - - 0 1 | win | WDL +2 | DTZ +7
test-13 | 8/3k1P1K/1R6/8/8/6r1/8/8 b - - 2 68 | hold | WDL +0 | DTZ +0
test-14 | 8/7k/8/6p1/3K4/8/2R5/4r3 b - - 0 1 | win | WDL +2 | DTZ +11
test-15 | 3k4/8/8/r7/4RP2/4K3/8/8 w - - 0 1 | win | WDL +2 | DTZ +13
test-16 | 3r4/1RP5/1K1k4/8/8/8/8/8 b - - 0 67 | hold | WDL +0 | DTZ +0
test-17 | 2R5/8/8/3r4/8/8/3p1K2/3k4 b - - 0 1 | win | WDL +2 | DTZ +13
test-18 | 8/8/1P6/3K4/8/k7/6R1/1r6 w - - 0 1 | win | WDL +2 | DTZ +7
playout-01 | R7/8/4k3/1P6/K7/8/8/2r5 w - - 0 1 | convert | WDL +2 | DTZ +15
playout-02 | 8/8/8/6R1/8/2K1p3/4rk2/8 b - - 0 1 | convert | WDL +2 | DTZ +7
playout-03 | 8/8/1RK5/r3k3/2P5/8/8/8 b - - 20 54 | hold | WDL +0 | DTZ +0
playout-04 | 8/8/3rk3/5p2/2R5/2K5/8/8 w - - 2 57 | hold | WDL +0 | DTZ +0
test-playout-01 | 8/8/8/6r1/3P4/2K2k2/R7/8 w - - 0 1 | convert | WDL +2 | DTZ +7
test-playout-02 | 8/8/2R2P2/4k3/6K1/8/r7/8 b - - 0 46 | hold | WDL +0 | DTZ +0
```

- Manual acceptance remains pending: Bruno should review the draft stage name, book pointer, all positions and line lengths, and play representative solves and play-outs when their boards exist. The tablebase confirms theoretical results, not the quality, difficulty or DTZ grading of the proposed lines.

## Resolution

Drafted the complete rook endgame unit and stage name; the position sources, all Syzygy results and the independent criterion check are recorded above. Bruno’s content, difficulty, line-length and stage-name review remains pending, along with playing the positions once the solving and play-out boards exist.

Gate: `godot --headless -s tests/run.gd` — 594 passed, 0 failed, exit 0 on 2026-11-08, tested commit `f573557fb057051aba65c09af4002c419d052841`. One graphical pixel check and six live Lc0 checks were skipped by the existing suite.

Gate evidence: /run/media/lage/New Volume/Scratch/LEARN-004/gate.json
