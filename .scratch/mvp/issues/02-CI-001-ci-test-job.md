# CI-001: CI test job
Stage: to-implement
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
