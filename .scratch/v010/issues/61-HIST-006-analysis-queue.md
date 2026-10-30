# HIST-006: The analysis queue
Stage: to-implement
Blocked by: REV-002, HIST-004
Review: agent
Difficulty: hard

- Primary files:
  - New: core/analysis_queue.gd
  - ui/history_screen.gd, ui/history_screen.tscn
  - ui/review.gd (Analyze jumps the queue)
  - ui/main.gd (pause while a game is played)
  - core/settings.gd (`analysis_threads`)
  - ui/settings.gd (its row)
  - New: tests/test_analysis_queue.gd
  - tests/test_settings.gd
  - docs/spec.md (§15.7, §15.10)

#### What to build

Games can be queued for analysis from the history, alone or in batches, and are analysed one at a time in the background (§15.7).

#### Acceptance criteria

1. Each card gets Analyze, or Re-analyze when its analysis is stale; cards can be multi-selected with "Analyze selected"; each tab has "Analyze all", which queues that tab's unanalysed and stale games.
2. Games run one at a time with the `analysis_threads` setting (Background, 1 thread, by default; or Max).
3. Cards show queued and "analysing x%"; a status line reads like "Analysing 2 of 7 · Background".
4. Review on a queued game, or Analyze in the review of an unqueued one, runs that game first on Max; the batch then resumes where it stopped, on its own setting.
5. The queue pauses when a game starts and resumes after it ends; the game never waits on Stockfish.
6. The queue survives restarting the app: queued games are still queued, and a game cut off mid-analysis starts over.
7. A game deleted while queued leaves the queue.

#### Verification

    Manual: Analyze all on a tab, start a game mid-batch, finish it, check it resumes; restart the app mid-batch.
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_analysis_queue.gd`, with a fake analyser: order and one-at-a-time; a jump-ahead runs on Max then the batch resumes; pause/resume around a game; a saved queue reloads; a deleted game leaves it (red: no queue).
- `tests/test_settings.gd`: `analysis_threads` default and choices.

## Comments

- 2026-10-30 Written from spec §15.7 and §15.10.
