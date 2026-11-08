# Pivot to a staged chess learning app

After v0.1.0 (a bullet and blitz trainer against Maia with game review), P-Chess becomes a learning app for players who don't know what to study: a course set by their rating, play-outs against Maia at their level, and the existing quick games kept as a sandbox. The research (`docs/research/learning-app.md`) found no competitor that combines all three; each exists alone (Noctie comes closest).

## Consequences

- Home leads with one Continue button; quick play moves below it and stays unchanged.
- Practice follows guided review (attempt, then the answer from an engine or tablebase), not a bare deck of your own mistakes, which the learning research (`docs/research/chess-learning.md`) rates as weak.
- Nothing in the course is locked, and the course map shows only content that exists: no "coming soon" units.
- Players with neither a chess.com nor a Lichess rating are out of scope for now.
