# CLEAN-015: Delete Review's unused help builders
Stage: to-implement
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

- 2026-11-06 Written from the grill ([spec](../spec.md)).
- Proxy decided (opus-5.5 xhigh): 9 settled, 2 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-141649-audit-fixes-c4b5e4.json)
- Proxy decided (opus-5.5 xhigh): 5 settled, 0 escalated (receipt C:\Users\bruno\AppData\Local\Temp\sweatshop-proxy\20261106-142124-audit-fixes-9f40af.json)
