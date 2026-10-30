# REV-001: A UCI bridge that can run a second engine
Stage: implementing
Blocked by: none
Review: agent
Difficulty: normal

- Primary files:
  - engine/uci.gd
  - ui/main.gd (only where it builds the bridge)
  - bot/maia_player.gd (only where it builds or reads the bridge)
  - tests/test_uci.gd

#### What to build

Prefactor, no behaviour change for Maia. `engine/uci.gd` hardcodes Lc0: its path, its error messages and its Lc0-only setup (`VerboseMoveStats`, policy parsing). Make the engine a parameter so a second instance can run Stockfish (REV-002), while Lc0's instance behaves exactly as today.

#### Acceptance criteria

1. A bridge is built for a named engine: its exe path under the search dirs and its display name ("Lc0", "Stockfish"). Missing-engine and stopped-engine messages use that name and still point at `scripts/fetch-engine.ps1`.
2. The Lc0-specific setup and the policy request stay available to the Maia bridge only; the Stockfish bridge sends neither.
3. A bridge can forward every raw `info` line of a search, with the final `bestmove`, to its caller, so REV-002 can parse MultiPV lines without changing the bridge again.
4. Two bridges can run at once, each with its own process, readers and queue; stopping one leaves the other running.
5. Every existing test passes unchanged except for construction call sites.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_uci.gd`: a bridge for "Stockfish" with no exe reports "Stockfish is missing (engine/stockfish/stockfish.exe)…" (red: always says Lc0); a fake-process bridge forwards info lines and bestmove to a callback (red: no forwarding).

## Comments

- 2026-10-30 Written from spec §15.3 ("through the same bridge as Lc0").
