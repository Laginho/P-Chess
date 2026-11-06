# CLEAN-015: Delete Review's unused help builders
Stage: done
Status: ready-for-agent
Blocked by: REV-010
Review: agent
Difficulty: easy

- Primary files:
  - ui/review.gd (`_class_help`, `_wrap_help`)

#### What to build

Spec: `.scratch/audit-fixes/spec.md`. Audit finding 6 (P3). Nothing calls `_class_help()`, and only `_class_help()` calls `_wrap_help()`. The help legend the Review shows is built in `_ready()`. Delete both.

#### Acceptance criteria

1. `_class_help` and `_wrap_help` are gone, and a repository-wide search (scripts, scenes, tests) finds no reference to either.
2. The Review's help legend is unchanged.
3. Gate green.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None. This is a deletion with no change in behaviour, so a passing gate is the check. Record the search in Comments.

## Comments

- 2026-11-06: Repository-wide `rg` found no references to either removed function outside historical Markdown records. The legend built in `_ready()` is unchanged. Gate: 569 passed, 0 failed, exit 0; no new test per ticket.
Gate evidence: C:\Users\bruno\AppData\Local\Temp\p-chess-clean-015-gate.json

- 2026-11-06 Written from the grill ([spec](../spec.md)).
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)

#### Resolution (2026-11-06)
Verdict: Approve

- Reviewed the complete diff `2134778...0b6302a` and all three stage-2 commits. Independent Standards and Spec reviewers found 0 issues each. Production scope is exactly the 29-line deletion in `ui/review.gd`; no review fixes were needed.
- Criterion 1: passed. Repository-wide search, including hidden files, found no `_class_help` or `_wrap_help` references in scripts, scenes or tests; only historical Markdown records remain. There are no remaining callers or dynamic signal references.
- Criterion 2: passed. The legend text, construction, opening/closing connections in `_ready()`, scene and existing legend tests are unchanged. Examined adjacent `_update_engine_lines`, `open_analysis`, `_check_engine` and the REV-010 cache-read interaction; cache behavior is untouched.
- Criterion 3: passed. Verified the existing receipt and log SHA-256 against the available tested commit `8d7e03219a1a157fa75da7aeb0e97abb40b83464` and identical production at the reviewed HEAD: `569 passed, 0 failed`, `ExitCode: 0`. Existing legend containment and routed keyboard tests passed in that run. The gate was reused, not rerun; the rebase was already up to date. `git diff --check` passed.
- Red/green: explicitly exempted by the ticket for this behavior-preserving deletion; no new tests required or added.
- Limits: no new graphical or live-Lc0 execution. The recorded gate skips one last-move pixel check and six Lc0 checks because a graphical display and `engine/lc0/lc0.exe` were unavailable.
- Integrated into `sweatshop/audit-fixes/2026-11-06-1433` with merge commit `5d729cb8a8936beae359f052927c278b9d4f6bcf`; no push or individual PR in the session flow.

Acceptance: passed | [Review legend](../../../ui/review.gd) and [existing regression tests](../../../tests/test_review.gd) are unchanged; the validated gate above and repository search satisfy all three criteria for this deletion.
