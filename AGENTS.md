# AGENTS.md

## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage roles, each label equal to its name. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Bindings do fluxo (skill `ticket-flow`)

- Gate: `godot --headless -s tests/run.gd`
- Godot: `godot` is `C:\Users\bruno\AppData\Local\Programs\Godot\godot.cmd` (Godot 4.7 console exe beside it). It is installed: if a sandbox denies reading it or writing `.git`, escalate the command; never download Godot.
- Base branch: `main`
