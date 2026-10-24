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
- Base branch: `main`
- Models: stage 2 gpt-6.1-sol high, hard gpt-6.1-sol xhigh, stage 3 gpt-6.1-sol xhigh
- Models (night): stage 2 haiku-5.5 high, hard opus-5.5 xhigh, stage 3 opus-5.5 xhigh
