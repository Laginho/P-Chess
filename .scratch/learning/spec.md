# Spec: the learning course, first unit (rook endgames)

Status: ready-for-agent

Source: the grill of 2026-11-07 (Q1–Q21, all settled), the research in `docs/research/`, and the approved design in `docs/design/learning/` (canvas https://claude.ai/artifact/RR5HJBpti7TqPz3Cjs4jhH). Vocabulary: `CONTEXT.md`. Decisions: `docs/adr/0001`–`0003`.

## Problem Statement

A club player who wants to improve doesn't know what to study, and the tools they have are separate: a puzzle app here, a course there, games against people or engines elsewhere. Nothing tells them, at their level, "do this next", checks that they can actually play it out, and brings back the mistakes they make in their own games. P-Chess v0.1.0 is a good place to play fast games against a human-like bot, but it teaches nothing.

## Solution

P-Chess becomes a staged learning app (ADR 0001). The player states their rating once, in one sentence, and gets the course for their stage. One Continue button on Home always knows what to do next. Each unit has four parts: a theory pointer that sends them to read, a set of positions they solve by entering whole lines graded by tablebase, play-outs against Maia at their level, and a pass test against a perfect opponent. When a reviewed game of theirs reaches the unit's ending and they change the result, the review links them to the unit and the position joins it. The fast games stay as the sandbox.

The first and only unit for now is rook endgames: Lucena and Philidor, rook and pawn against rook.

## User Stories

Rating and stage

1. As a new player opening the course for the first time, I want to state my rating in one sentence ("I'm rated [1600] in rapid on [chess.com ▾ / lichess]"), so that the course fits me without a placement test.
2. As a Lichess player, I want to type my Lichess rating, so that I don't have to convert it myself (Lichess = chess.com + 300, ADR 0003).
3. As a player, I want my rating shown on the chess.com scale everywhere, so that one number means one thing.
4. As a player whose rating changed, I want to edit the rating sentence in Profile, so that my stage and Maia's level follow.
5. As a player, I want the first-open dialog to have no skip, so that the course never runs without a stage.

Home and Continue

6. As a returning player, I want a large Continue card first on Home, naming the unit and where I am ("Continue: Rook endgames, solving 4/12"), so that I can start in one click.
7. As a player with a review check due, I want Continue to offer it before anything else, so that I keep what I mastered.
8. As a player whose game produced a new position for a unit, I want Continue to offer it next, so that my own mistakes come back while they're fresh.
9. As a player mid-unit, I want Continue to open the next unfinished part, so that I follow the unit in order without thinking.
10. As a player who finished every part, I want Continue to move to the next unit, or, when there is none, say "Unit done, go play some slow games" and point to the sandbox.
11. As a player, I want Home's board to show the position Continue will open, so that I see what's waiting.
12. As a player who only wants fast games, I want quick play (1+0, 3+2, 5+0, the Maia level, Custom) still on Home, so that nothing I used is gone.

Course map and unit page

13. As a player, I want a course map that shows only my stage and its real units with their status (new, in progress, mastered, needs review), so that I'm never shown "coming soon".
14. As a player, I want every part of a unit to open from the unit page, so that nothing is locked.
15. As a player, I want the unit page to show each part's progress and my first-try rate, so that I know how well I'm doing, not only how far.
16. As a player, I want to switch the play-out clock between 5+5 and no clock on the unit page and have it remembered, so that I can practise without time pressure.

Theory pointer

17. As a player, I want a one-line goal, a few search terms and book chapters, so that I read the real theory where it is best explained.
18. As a player, I want the theory pointer to count as done once I've opened it, so that reading elsewhere isn't something the app pretends to check.

Solving

19. As a player, I want to enter a whole line without the pieces moving, seeing only faint red marks on the squares, so that I calculate instead of watching the board.
20. As a player, I want no arrows while entering, so that the board doesn't visualise the line for me.
21. As a player, I want to see the line I've entered as text, undo the last move (Backspace) and clear it, so that I can fix a slip before committing.
22. As a player, I want Enter to commit the line, so that solving is fast with the keyboard.
23. As a player, I want each position to say which side I play, whether I'm winning or holding, and how many of my moves the line needs, so that I know when I'm done.
24. As a player, I want my moves graded by tablebase, each one keeping the result without a slow detour, so that the grading is exact.
25. As a player, I want the opponent's moves in my line only checked for legality, with a better defence shown but not held against me, so that I'm judged on my own moves.
26. As a player, I want the committed line played back with ✓/✗ and, at the first ✗, the correct move and line, so that I see exactly where I went wrong.
27. As a player, I want Next and Retry after feedback, with a retry not counting as first try, so that my first-try rate stays honest.
28. As a player, I want solving done once every position is solved once, with the first-try rate shown apart, so that finishing and quality are both visible.
29. As a player, I want positions from my own games marked "From your game", so that I know why they're there.

Play-outs

30. As a player, I want four play-outs, two to convert and two to hold, against Maia at my level, so that I prove I can play the ending against a human-like opponent.
31. As a player, I want a play-out to fail as soon as my move changes the tablebase result, or on time, so that I learn the exact moment it went wrong.
32. As a player, I want to pass a convert by promoting or mating, and a hold when the pawn is gone or after 30 moves held, so that the goal is clear.
33. As a player, I want the end card to show the losing move and a move that kept the result, with Retry and Back to the unit, so that I can try again at once.

Pass test and mastery

34. As a player, I want a pass test of 6 positions I haven't seen, drawn from a pool of about 18, needing 5 first try, so that mastery means I can solve fresh positions.
35. As a player, I want the test's two play-outs (one convert, one hold) to be against a perfect opponent with no clock, so that only correct play passes.
36. As a player, I want to retry the test any time with fresh positions, and a result card that shows each miss with my move and the best one, so that a failed test still teaches.
37. As a player who passed, I want the unit marked mastered, so that the course map shows it.
38. As a player with a mastered unit, I want Continue to offer a 3-position review check after 7 days and again after 30, so that I keep it.
39. As a player who misses a review check, I want the unit marked "needs review" while the mastered badge stays, so that I'm nudged, not punished.

Own games

40. As a player reviewing a game that reached rook and pawn against rook, I want the move where I changed the tablebase result marked in the move list with a link to the unit, so that my mistake leads straight to practice.
41. As a player, I want that position added to the unit's solving positions as "From your game", and Continue to suggest the unit even after it's mastered, so that my own mistakes get fixed.

## Implementation Decisions

Numbered so tickets can cite them (`spec §L3`).

**L1. Course data.** The course ships as JSON under `data/course/`. A course index lists the stages (name, rating range on the chess.com scale, units in order); with one stage for now, it covers every rating. Each unit file holds: id, title, subtitle; the theory pointer (goal line, 3–5 search terms, 1–2 books with the chapter); the positions, each with FEN, the side you play, the goal (win or hold), the line length in your moves, and its pool (practice or test); the default line length for from-your-game positions (`default_line_length`, 3 for rook endgames); the 4 play-outs (FEN, side, convert or hold); and the test's play-out positions (one convert, one hold). The practice pool has 12 positions, the test pool about 18.

**L2. Progress.** Everything the player does in the course is saved in one JSON file, `user://course.json`: the rating sentence (number and site), the play-out clock choice (5+5 or none, default 5+5), and per unit: theory opened, each practice position's state (solved, first try), play-outs passed, test attempts (date, positions used, result), the mastered date, review checks (due, done, missed), and the from-your-game positions. A missing or unreadable file starts empty; it is never overwritten with less than it held because of a read error.

**L3. The course module.** One logic-only module owns the course rules, with no UI and no engine: it reads the data (L1) and the progress (L2), takes the current time as an argument, and answers: each unit's status (new, in progress, mastered, needs review), each part's progress, the first-try rate, the next Continue target (§L9), and the review checks due. It records commits, play-out results and test results. Screens and engines call it; it calls neither.

**L4. Rating.** The rating sentence stores the number and the site. On the chess.com scale, a Lichess number is shown minus 300 (ADR 0003). The course's Maia level is the chess.com number plus 300, rounded to the nearest hundred (halves up) and clamped to 1100–1900, the nets already bundled. The rating sets the stage (L1) and the course's Maia level; the sandbox keeps its own level picker.

**L5. Tablebase probe.** Grading never asks an evaluation engine for a judgement. It asks a probe what a position is worth. For a position, the probe answers from the side to move:

- win, draw or loss under the 50-move rule. A cursed win counts as a draw, and so does a blessed loss, because the game ends at 100 half-moves.
- for each legal move, the mover's result and its distance to zeroing, in plies from this position with the move included. A capture, pawn move, promotion or mate that keeps a win is 1.
- the best move: the best result; then for a win the smallest distance, for a loss the largest; then UCI order.

The real probe is a small helper built from Fathom (MIT) that reads the bundled tablebase files (§L12). RES-001 found that Stockfish computes these distances but does not expose them through UCI. The helper speaks a UCI subset over the engines' bridge and sees only the position (FEN, with its half-move clock), not the game's history. A position it cannot answer is a probe failure that the caller shows: castling rights, material without a bundled file, a missing or unreadable file, or a helper that stopped. A failure is never replaced by an engine evaluation. Everything that grades (solving, play-out fail checks, the review marker, the perfect opponent) goes through this one probe, so tests use a fake.

**L6. Grading a line.** A committed line has your moves and the opponent's moves in between, starting and ending with yours (line length N means 2N−1 plies). Each of your moves must keep the result for your side; when winning, it must also not detour: the distance to zeroing after your move may be at most the best move's plus a margin (a tunable). Opponent moves only need to be legal; where a better defence existed it is shown, but it doesn't fail you. Grading stops at your first failing move. A position is solved when its first commit, or any later one, has no failing move; it is first try only when its first commit passes. Solving is done when every practice position is solved once.

**L7. Entering a line.** The solving board shows the position and never moves the pieces. Each entered move marks its two squares with a translucent red under the pieces, darker on a square used twice (values in `docs/design/learning/README.md`, "Entry marks"); no arrows while entering. Moves are checked for legality against the position after the line so far. The line fills after N of your moves; Backspace undoes one ply, Clear empties the line, Enter commits a full line. Feedback plays the line back one ply at a time with ✓/✗ on your moves, stops at the first ✗, and shows the correct move (an arrow is fine here) and the correct line of N moves. Next and Retry follow.

**L8. Play-outs and the pass test.** A play-out is a game from the position's FEN: you against Maia at the course level (L4) with the unit's clock choice, or, in the pass test, against the perfect opponent (the probe's best move) with no clock. After each of your moves the probe checks the result: it fails at once when your move changes the result for your side, or when you run out of time. A convert passes on promotion or mate; a hold passes when the pawn is gone, after 30 of your moves (a tunable), or when the game ends drawn before that (stalemate, repetition, the 50-move rule or insufficient material). Play-outs are drills: they are not saved to History and don't count in Profile's stats. The pass test draws 6 test-pool positions, preferring ones not used in your previous attempt; it passes with at least 5 first try (a tunable) and both play-outs passed. Passing records the mastered date.

**L9. Continue.** Continue's target, in order: a review check that is due (3 positions drawn from the unit's practice and test pools, offered 7 days and again 30 days after the mastered date); then any from-your-game position not yet solved; then the next unfinished part of the current unit (theory pointer, solving, play-outs, pass test); then the next unit. With nothing left it shows "Unit done, go play some slow games" and points to the sandbox. A review check with a failed position marks the unit "needs review"; the mastered date and badge stay, and passing a later check clears it.

**L10. From your game.** When Review shows a game that reached rook and pawn against rook (K+R+P vs K+R, either colour, at least once), the probe checks each of your moves in that material: a move that changed the result for your side gets a marker row under it in the move list, in the "Left repertoire" pattern, linking to the unit. The position before that move joins the unit's positions as "From your game" (your side, goal from the probe's result before the move, the unit's default line length), once per position.

**L11. Screens.** Course map, unit page, theory pointer, solving, play-out and pass test are new screens owned by `ui/main.gd` like Review and History, each with a `present(...)` entry and a back signal. Home changes as in the design (Continue card first, Course button, Play row with Custom). Layout follows `docs/design/learning/`; where the design and this spec disagree, this spec wins.

**L12. Tablebase files.** Only the files this unit needs are bundled (rook and pawn against rook and the smaller endings it can turn into), fetched with pinned hashes like the engines, and listed in `docs/THIRD_PARTY.md`. The probe helper (§L5) is built by `scripts/build-tbprobe.ps1` from a pinned Fathom commit and ships at `engine/tbprobe/`. Its MIT notice ships in `licenses/` and `docs/THIRD_PARTY.md`.

## Testing Decisions

- Test what the player sees and what the course remembers, not how a module stores it. A good course test sets up data and progress, acts (commits a line, finishes a play-out, moves the date forward), and checks the answer to a question the UI asks: the status, the Continue target, the first-try rate.
- **Seam 1: the course module (L3).** Logic tests with fixture data in `tests/fixtures/course/`, progress in a temporary `user://` folder, and the time passed in. Covers statuses, Continue order, first try, mastery, review checks, from-your-game positions. Prior art: `tests/test_history.gd`, `tests/test_settings.gd` (isolated files).
- **Seam 2: the tablebase probe (L5).** The grader, the play-out fail check, the perfect opponent and the review marker run against a fake probe with scripted answers. The probe's adapter (`engine/tablebase.gd`) is tested through the fake UCI engine with scripted helper lines, like `tests/test_uci.gd` and `tests/test_analyser.gd`. The helper is tested against the real bundled files when they are present, and skipped otherwise, like the live Lc0 tests. Its Windows build is checked by a CI job that builds it and runs one real probe.
- **Existing seams for the rest.** Screens through `ui/main.tscn` with `Session.HeldBridge` and a temporary history folder (`tests/test_home.gd`, `tests/test_profile.gd`, `tests/test_review.gd`); the board through `tests/test_board_view.gd`; starting from a FEN through `tests/test_maia_player.gd` and `tests/test_pgn.gd`; time controls through `tests/test_clock.gd`.
- What these seams can miss: a fake probe can't catch a wrong reading of the real tables (the real-file tests, checked against an independent reader as in RES-001, cover that; CI skips the full real-file suite, while the Windows job uses only KRvK smoke tables), and headless screen tests can't judge layout (the design PNGs and the screenshot harness `scripts/screens.gd` do). Reversing either choice means adding an end-to-end test with the real engine, which is slow and needs the binaries in CI.
- Gate: `godot --headless -s tests/run.gd`.

## Acceptance scenarios

1. Fresh profile, open the course: the rating dialog appears with no skip; enter 1600 chess.com; the course map shows the rook endgames unit as new; Profile shows the same sentence. (Bruno, by hand.)
2. Enter a correct 3-move line in the Lucena position: playback shows ✓ on all three, the unit page shows 1/12 solved and 100% first try. Enter a line with a slow detour on a second position: it stops at that move with the correct line, and a retry that passes counts as solved, not first try. (Bruno; independent reference: the Lichess tablebase for each position.)
3. In a hold play-out, play a move that loses: the end card appears at once with that move and a holding move. (Bruno; reference: the Lichess tablebase.)
4. Pass the test, move the clock 7 days forward (test only) or wait: Continue offers the 3-position review check before anything else. (Tests.)
5. Review a game that reached rook and pawn against rook where you lost a draw: the move list shows the marker; its link opens the unit, where the position appears as "From your game", and Continue offers it. (Bruno, with a real game.)

### Session check (2026-11-08, foreman, session `sweatshop/learning/2026-11-07-2234` at `66abb54`)

Evidence reused from the integrated session's last gate (`godot --headless -s tests/run.gd`, 677 passed, 0 failed, CLEAN-020's receipt; the code is identical at the session head). Real-file tablebase tests ran with the Linux Fathom helper; six live Lc0 checks and two pixel checks were skipped (no Linux Lc0 or display in the lane clone).

1. Rating dialog, map, Profile sentence: pending (Bruno). Automated: LEARN-001/LEARN-002 tests in `tests/test_home.gd`, `tests/test_profile.gd`, `tests/test_course_screens.gd`, plus LEARN-001's review captures. Not examined: physical Escape/click-outside, real fresh profile.
2. Lucena line and slow detour: pending (Bruno). Automated: LEARN-006 grading tests at the fake-probe seam, plus the real-helper Lucena flow that LEARN-006's review ran (13/13 targeted). Not examined: a person entering the line on screen, Lichess reference per position.
3. Losing move in a hold play-out: pending (Bruno). Automated: LEARN-007 play-out tests; its review checked hold and convert against the real tablebase. Not examined: a real Maia (Lc0) reply, a person playing.
4. Review check at 7 days: passed. `tests/test_course.gd::test_continue_offers_review_checks_at_seven_and_thirty_days` (day 6 no, day 7 review with 3 distinct positions, ahead of a from-your-game entry; 30 days; local calendar), `tests/test_home.gd::test_continue_shows_and_opens_the_due_review_position`, `tests/test_course_screens.gd::test_review_check_grades_three_positions_once_and_keeps_mastery`.
5. From-your-game marker on a real lost draw: pending (Bruno, real game). Automated: REV-011 tests and its review's real-probe check. Not examined: a saved real game and the marker's look.

Acceptance: pending | scenario 4 passed on the integrated session; 1, 2, 3 and 5 wait for Bruno's hand checks listed above.
Disclosure: decision | release | [LEARN-006 split](issues/110-LEARN-006-grading-and-feedback.md), receipt `/tmp/sweatshop-proxy/20261108-020737-LEARN-006-0937d8.json`: the proxy replaced spec L5's Stockfish-only probe with a native Fathom helper (LEARN-010, `703fe57`). RES-001's review had reserved that contract change for Bruno; confirm or reverse it before merging.
Disclosure: pending | release | Windows: the Fathom helper build (MSVC, static CRT), the windows-latest CI smoke job, the accented-folder release start and RES-001's Windows probe were not run on this Linux box.
Disclosure: pending | release | Real Maia: no Linux Lc0 in the lane, so course play-outs (CORE-007, CLOCK-003, LEARN-007, LEARN-008) never met a real Maia reply.

## Out of Scope

- Any unit other than rook endgames, and any stage content beyond the one unit. No placeholders for them.
- Players with neither a chess.com nor a Lichess rating.
- Profile changes beyond the rating sentence; course stats in Profile.
- Maia-3, and any AGPL code inside the app (ADR 0002). Replacing the Lichess sounds (needed only before a paid version).
- A theme tagger for other endings. Only the rook-and-pawn-against-rook check in review is built.
- Explanatory text inside the app (the theory pointer only points).
- Accounts, sync, or importing games from chess.com or Lichess.
- Saving play-outs to History or counting them in Profile's stats (§L8).

## Tickets

In `.scratch/learning/issues/`, build order: RES-001, CORE-007, CLOCK-003, CI-005, LEARN-001 to LEARN-005, LEARN-010, LEARN-006 to LEARN-009, REV-011. Each lists its blockers.

## Further Notes

Facts to check before or during the build (not Bruno's decisions):

- which tablebase files rook and pawn against rook needs (plus the smaller endings it can turn into), and their size;
- how the bundled Stockfish loads them (`SyzygyPath`);
- how Maia-1 behaves in rook endgames (risk: odd defence that makes holds too easy or converts too hard);
- the size of the Lichess puzzle and game databases if used to pick positions.

Content: Claude drafts the unit's data (positions, line lengths, practice and test pools, theory pointer text); Bruno tunes it. The Course map's stage name and the theory pointer's book chapters are still open.
