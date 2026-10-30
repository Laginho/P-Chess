# UI-014: Match score across rematches
Stage: implementing
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - ui/main.gd
  - ui/main.tscn (a score box beside each clock)
  - ui/game_over.gd
  - ui/game_over.tscn
  - tests/test_session.gd
  - docs/spec.md (§9.1)

#### What to build

Consecutive rematches form a match (§9.1). The game-over panel shows the running score between you and Maia, and from the first rematch on each player's score shows in a small box beside their clock.

#### Acceptance criteria

1. A win counts 1 to the winner, a draw ½ to each side; scores show as "1", "½", "1½".
2. The game-over panel shows the running score including the game just finished, you first, for example "You 2 – 1 Maia 1500".
3. From the first rematch onwards each clock row shows that player's score in a small box; the first game of a match shows no boxes.
4. A rematch (`Space` or the button) keeps the score, and the boxes follow the players across the colour swap.
5. The score resets on New game, when a game starts with any setting other than the swapped colour changed, and when the engine stops. It is not saved across launches.

#### Verification

    Manual: win, rematch, draw, rematch: the panel reads 1½ – ½ and the boxes follow the colours.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_session.gd`: two finished games via rematch give the right panel text and boxes after the swap; New game resets; a changed level resets (red: no score).

## Comments

- 2026-10-30 Written from spec §9.1. The Home screen (UI-016) adds the reset on returning Home.

- 2026-10-30 Stage 2: red test failed because the score boxes were absent; final headless gate passed. Manual win, rematch, draw, rematch and visual layout remain pending.

Acceptance: pending | Stage-3 findings below, then manual win, rematch, draw, rematch and visual inspection of the score boxes.
Disclosure: pending | release | Manual match-score and layout acceptance remains to be performed.
Gate evidence: C:/Users/bruno/AppData/Local/Temp/ui014-gate-box.json

#### Resolution (2026-10-30)
Verdict: Reopen — criterion 3 fails after a rematch ends; new score boxes regress focus mode.

Standards: no findings. Primary-files scope and the test/production commit split are respected. No relevant documented-standard breach or code smell was found.

Spec: two P2 findings, both confirmed by a focused headless probe on `b0a1558ccbf6cf5c0511db131e4a900b434f7c5e`:

1. **P2 — stale clock-row scores after a finished rematch** (`ui/main.gd:442`, labels assigned only at `254–255`). Criterion 3 requires each clock row to show that player's score from the first rematch onwards. Win as White, rematch as Black, draw, then close the game-over panel: the panel says `You 1½ – ½ Maia 1700`, but the visible Black/human box still reads `1` and the White/Maia box `0`. Refresh the score labels when the result is counted. Extend `tests/test_session.gd` to assert both totals before starting another rematch, including after closing the panel.
2. **P2 — score boxes remain visible in focus mode** (`ui/main.gd:252–253`; `_set_focus` at `370–375`). This regresses `docs/spec.md:216`: F11 shows "only the board and the clocks". After a rematch, toggling F11 leaves both score labels visible; starting a rematch with focus already active also shows them. Make score visibility respect both match state and focus in these paths. Test entering/leaving focus during a rematch and starting a rematch while already focused; leaving focus in the first game must keep boxes hidden.

Numbered criteria: 1 ✅, 2 ✅, 3 ❌ (finding 1), 4 ✅, 5 ✅. Finding 2 is a regression of the existing focus contract. The passing criteria reflect code inspection and existing test evidence, not completed product acceptance.

Coverage: all seven changed files (this ticket, `docs/spec.md`, `tests/test_session.gd`, `ui/main.gd`, `ui/main.tscn`, `ui/game_over.gd`, `ui/game_over.tscn`). Examined callers and interactions: keyboard/panel/review rematches, New game/setup, changed game settings, engine-stop reset, result paths for resignation/flag/draw/moves, repeated-result deduplication, history-save failure, player/colour ownership, board flip, focus, and setup/review navigation. No production repair was authored during review. Physical input, rendered layout, screen-reader behavior and live Lc0 gameplay were not independently exercised in this review.

Verification: the stage-2 red log `C:/Users/bruno/AppData/Local/Temp/ui014-red.log` records the missing-box failure (281 passed, 1 failed). The final receipt above tests `5f02ee7c26f02dbc7ba112a1d1492545343271f2`: 282 PASS lines, no explicit SKIPs, 0 failed, exit 0. Its command, log SHA-256, commit and unchanged-code status were validated with `Assert-GateEvidence`; only ticket metadata changed since that run, so the full gate was reused. The focused probe `C:/Users/bruno/AppData/Local/Temp/ui014-stage3-probe-20261030.gd` and its `.log` confirm both findings, exit 1, without script errors. Headless visibility checks do not establish manual/visual acceptance.

Disclosure: pending | integration | Both P2 findings above must be fixed and reviewed before session integration; probe evidence: C:/Users/bruno/AppData/Local/Temp/ui014-stage3-probe-20261030.log.

Return to stage 2 on the existing branch for these two findings only. Keep the manual match-score/layout acceptance as a release condition after the fixes.
