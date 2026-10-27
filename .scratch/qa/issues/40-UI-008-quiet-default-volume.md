# UI-008: Start at 20 % volume
Stage: done
Status: ready-for-agent
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - core/settings.gd (the `volume` default)
  - tests/test_settings.gd
  - docs/spec.md (§10 table, Volume row)

#### What to build

A first launch plays sounds at 20 % instead of 100 %. Full volume on top of the Windows volume is too loud (Bruno's QA, 2026-10-26). A saved volume is kept as it is.

#### Acceptance criteria

1. With no `settings.cfg`, `get_value("volume")` is 20, and Main sets the master bus to `linear_to_db(0.2)` at startup.
2. A saved volume (any value 0–100) still loads unchanged; an invalid saved value falls back to 20.
3. §10's Volume row reads `20 %`.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_settings.gd`: the existing default/fallback assertions expect 20; red because the default is 100.

## Comments

- 2026-10-26 Written from Bruno's first QA session (item 1).

- Stage 2: red at 85f0056 (249 passed, 5 failed: default 100 instead of 20); green at f104999 (254 passed, 0 failed). Saved volumes 0, 50 and 100 reload unchanged. Main applies each stored setting at startup.
- Gate evidence: C:\Users\bruno\AppData\Local\Temp\ui-008-green.json

#### Resolution (2026-10-27)
Verdict: Approve

- Standards: 0 findings. Independent review covered the complete diff, repository rules, surrounding GDScript, and settings/audio callers; no violations or baseline smells.
- Spec: 0 findings. Independent review covered all numbered criteria and Primary files; no missing behavior or scope creep.
- Criterion 1: passed. Missing settings return 20; Main's startup applies every stored setting. An isolated headless Main startup observed master volume -13.9793996810913 dB, matching `linear_to_db(0.2)` (-13.9794000867204 dB).
- Criterion 2: passed. Saved 0/50/100 reload unchanged, rejected values leave the default, and invalid/corrupt files fall back to 20. Validation and persistence are unchanged.
- Criterion 3: passed. The Volume row in docs/spec.md section 10 reads `20 %`.
- Examined callers and interactions: Settings loading/get/set/valid, Main initialization and `_apply`, settings SpinBox, and SoundPlayer's master-bus routing. Missing/corrupt settings, range endpoints, invalid saved values, and startup-before-engine behavior were checked. No manual listening or Windows export was performed in review.
- Scope: core/settings.gd, tests/test_settings.gd, docs/spec.md, and ticket bookkeeping only. Commit statistics confirm test-only red 85f0056 before production-only b0e6dd7 and documentation f104999; no review production fixes.
- Red-green proof: the recorded red gate has 249 passed, 5 failed (each expected 20, got 100); the green gate at f104999 has 254 passed, 0 failed, exit 0. The receipt and SHA256 log hash were verified; unchanged tested code reuses that run.
- Startup check: C:\Users\bruno\AppData\Local\Temp\ui-008-startup-review.log (exit 0); storage and the engine were isolated using the existing test harness. The external check's initial type-inference error was corrected before the passing run; no repository code changed.
- Acceptance: passed | tests/test_settings.gd, validated green gate, and the isolated Main startup check above.
- Integration: no session branch; rebase onto origin/main and merge through a PR to main after CI succeeds. Preserve the root checkout's uncommitted project.godot.
- Integrated: [PR #19](https://github.com/Laginho/P-Chess/pull/19), merge fd3df27; [CI](https://github.com/Laginho/P-Chess/actions/runs/40508481796) passed both test and windows-export on head 5a71bbc. Root main fast-forwarded with project.godot's SHA256 unchanged; this closure and the ledger entry are committed together.
