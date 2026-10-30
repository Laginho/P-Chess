# HIST-003: Save the repertoire snapshot beside the PGN
Stage: to-review
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/history.gd (`save`)
  - ui/main.gd (`_show_result`: pass `_review_repertoire`)
  - tests/test_history.gd
  - docs/spec.md (§15.7)

#### What to build

When a game is played with a repertoire loaded, the lines it was checked against (the snapshot `ui/main.gd` already keeps for the review) are saved next to the PGN as `<game file name>.repertoire.json` (§15.7). A review opened later from the history (HIST-004) checks Repertoire and Left repertoire against that file, never against the repertoire as it is now.

#### Acceptance criteria

1. Saving a game with a non-empty snapshot writes `<stem>.repertoire.json` beside `<stem>.pgn`, holding those lines and the repertoire's colour, in a form `bot/badges.gd` can read back unchanged.
2. A game with no repertoire writes no snapshot file.
3. A failed snapshot write reports through `history.error` like a failed PGN write, and the PGN and stats are still saved.
4. A function reads a game's snapshot back, returning empty lines when the file is missing.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_history.gd`: a save with lines writes the file and reads back equal; a save without writes none; a missing file reads as empty (red: no file).

## Comments

- 2026-10-30 Written from spec §15.7.

- 2026-10-30 Review ended at blocked (exit 0); branch HIST-003 holds the review; left for a human

- 2026-10-30 Proxy decided (opus-5.5 xhigh): Approve. Criterion 4 requires the reader and criterion 1 requires the colour, so both edits are authorized. Stage 1 does not need to clarify anything first. Fold the widened scopes below into Primary files so the boundary matches what was merged - both edits sit in files the ticket already names, and the numbered criteria require them. (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261030-195501-HIST-003-ed4474.json)
  Primary-files interpretation: criteria 4 (snapshot reader) and 1 (repertoire colour) required `read_repertoire` in `core/history.gd` and the colour capture in `ui/main.gd` `_start`. Both files were already named. Scopes widened to match, numbered criteria unchanged. Asked by the foreman after stage 3 (gpt-6.1-sol xhigh) blocked with the proxy unreachable from Codex; resume stage 3 on the retained `HIST-003` branch (abb5e93).
