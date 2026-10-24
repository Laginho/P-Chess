# CI-001: CI test job
Stage: done
Blocked by: CORE-001
Review: human
Difficulty: normal

- Primary files:
  - New: .github/workflows/ci.yml

#### What to build

Every push runs the test suite on GitHub Actions (§12), so a red test shows on the branch before review: Ubuntu runner, Godot 4.7 headless, the same command as the local gate.

#### Acceptance criteria

1. The workflow runs on every push to any branch.
2. The job runs on `ubuntu-latest`, downloads a pinned Godot 4.7 Linux build from its official release URL, and runs `godot --headless -s tests/run.gd`.
3. The job fails when the runner exits non-zero.
4. The job does not need `engine/` (lc0 is not on the runner); tests that need lc0 skip themselves there.

#### Verification

    gh run watch   # on the pushed ticket branch: one green run, linked in the ticket
    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- None at a GDScript seam: a workflow file has no unit test. The evidence is the link to the green run on the ticket branch.

## Comments

- 2026-10-24 Stage 2: CORE-001 is done on the session base. No unit-test commit is required by this ticket; verification is the pushed workflow run plus the local gate. The existing tests use explicit script paths and do not require lc0 or an import cache.

- 2026-10-24 Stage 2 handoff on `ci-001`:
  - Implementation: `.github/workflows/ci.yml` runs on every push without branch/path filters, on `ubuntu-latest`, with read-only repository permission and a 15-minute timeout. It downloads the official pinned Godot 4.7.2 Linux x86_64 archive, verifies SHA-256, installs `godot`, and runs exactly `godot --headless -s tests/run.gd`.
  - Scope and failure paths: only the new workflow and this ticket changed. No GDScript function changed. The workflow invokes the existing test runner directly; it has no exit-code masking or `continue-on-error`. The existing runner tests exercise failing assertions, unloadable scripts and runtime errors through child Godot processes. No engine download or import step is needed; the fresh Linux checkout passed without `engine/`.
  - Test exemption: the ticket explicitly requires no new GDScript unit test. The workflow did not exist on the session base; its integration proof is the real Actions run, rather than an artificial YAML unit test.
  - Commits: `9260bec` starts implementation (metadata only), `9c938b4` adds the workflow, and `3e56a02` updates checkout to the official v7.0.1 release after the first green run reported checkout v4's deprecated Node 20 runtime. The final run uses Node 24 without that warning.
  - Final GitHub Actions proof: [green push run 40110593945](https://github.com/Laginho/P-Chess/actions/runs/40110593945), commit `3e56a0260009f05b8814cd8d91e6bc7d3c96063b`, Ubuntu, Godot `4.7.2.stable.official.ed1daf0bf`, checksum OK, **78 passed, 0 failed**. `gh run watch 40110593945 --exit-status` exited 0.
  - Local gate on the same final implementation commit: **78 passed, 0 failed**, exit 0. Receipt and hashed log are recorded below. `git diff --check` passed; final diff and per-commit scope were inspected.
  - Stage 3 remains pending; no merge or PR was performed during implementation.

Gate evidence: C:\Users\Lage\AppData\Local\Temp\P-Chess-CI-001\final-gate.json

Acceptance: passed | [final Linux push run](https://github.com/Laginho/P-Chess/actions/runs/40110593945) and the local gate both passed 78/78 on `3e56a02`.

#### Resolution (2026-10-24)

Verdict: Approve

Stage 3 reviewed `git diff e5dd8dc...1183fa6`, including every implementation commit. No production fix was needed.

Standards: the independent Standards reviewer found no documented-standard violations or baseline smells. The workflow is simple and scoped to the sole Primary file. Commits `9260bec` and `1183fa6` contain only ticket metadata; `9c938b4` and `3e56a02` contain only the workflow. The ticket explicitly exempts new unit tests, so no test-first violation applies.

Spec: the independent Spec reviewer found no missing requirements, incorrect implementation, or scope creep. Windows exports and releases remain the separate CI-002 and CI-003 contracts.

Criteria:

1. Passed: `on: push` has no branch or path filter. The verified Actions run was triggered by a push to `ci-001`.
2. Passed: the job uses `ubuntu-latest`, the official pinned Godot 4.7.2 Linux x86_64 release, and exactly `godot --headless -s tests/run.gd`. The official release API confirms the archive URL and SHA-256 `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`; the Actions log confirms the checksum and Godot version.
3. Passed: the test command runs directly under the logged `/usr/bin/bash -e {0}`, with no error suppression or `continue-on-error`. Existing runner tests cover failed assertions, unloadable scripts and runtime errors through child Godot processes. Review also ran `godot --headless -s tests/run.gd -- tests/fixtures/failing`: `0 passed, 1 failed`, exit 1 as expected.
4. Passed: the fresh Ubuntu checkout passed without downloading lc0 or weights. No currently discovered test or preload chain requires lc0, so no applicable test needs a new skip condition.

Examined: push-to-checkout-to-install-to-run flow; official Godot archive and checksum; checkout v7.0.1's official Node 24 declaration; direct command failure propagation; `tests/run.gd`, `tests/test_runner.gd` and their failing fixture; test discovery and current engine dependencies. No GDScript function or caller changed. Not exercised: a deliberately failing hosted Actions run, future lc0 integration tests, or the later Windows export/release workflows.

Verification: independently fetched [Actions run 40110593945](https://github.com/Laginho/P-Chess/actions/runs/40110593945) and job `120921299344`. The push run completed successfully on `3e56a0260009f05b8814cd8d91e6bc7d3c96063b`; its Ubuntu log contains 78 PASS lines and `78 passed, 0 failed`. The existing local gate receipt records the same tested commit, bound command and exit 0; its log hash and exit-status footer were verified with `Assert-GateEvidence`. Only this ticket and its ledger changed after the tested production, so the green receipt is reused. `git diff --check` passed.

Red-green proof: new GDScript tests are expressly exempt for this workflow-only ticket. The workflow was absent at the session base; the real pushed workflow supplies its integration proof, and the existing failing fixture supplies the local negative-path check.

Integration: rebasing onto `sweatshop/mvp/2026-10-24-1310` was already up to date. Merged `ci-001` into that session with `--no-ff` as `869468f`; no production changed during review or integration. This resolution, `Stage: done` and the ledger entry are committed together on the session. `Review: human` remains visible for the eventual session PR, as required by ticket-flow.

Proxy decided lines: none. No contract change, pending product check or unresolved defect was found.

Acceptance: passed | independently verified Ubuntu push run and unchanged-production local gate, both 78 passed, 0 failed; expected failing fixture exited 1.
