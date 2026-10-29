# Design brief: P-Chess v0.1.0 screens

Paste this into `/design`. The artboards are a visual reference only. The app is built in **Godot 4** (GDScript, Control nodes), so keep effects simple: flat panels, borders, rounded corners and plain text. No blur, no web-only CSS tricks.

## The app

P-Chess is a native Windows app for bullet and blitz practice against **Maia**, a human-like chess bot. Levels are named after the net: "Maia 1100" to "Maia 1900". There are three time controls only: 1+0, 3+2 and 5+0. v0.1.0 adds a chess.com-style game review powered by Stockfish, a game history and a home screen.

## Fixed constraints

- The window opens at 1280×800, can be resized down to 800×600, and the board scales with it. Design at 1280×800 and show one 800×600 variant of the review screen.
- Dark UI, like chess.com and Lichess.
- **Board:** Lichess brown squares (`#f0d9b5` light, `#b58863` dark), cburnett pieces, coordinates inside the squares, and a yellow-green highlight for the last move.
- All strings are in **English**.
- **Move-classification colours:** match chess.com's palette (look it up rather than inventing values). The icons are our own, drawn in chess.com's style: chess.com's icons are proprietary, so don't copy them.
- **Classes**, best to worst: Brilliant (!!), Great (!), Best (★), Excellent, Good, Book (brown book), Repertoire (the same book icon in **blue**), Inaccuracy (?!), Mistake (?), Miss (✕), Blunder (??), Forced.

## Screens

### 1. Home (the app opens here)
- Three large quick-play buttons: **1+0**, **3+2** and **5+0**. Each reuses your last level, colour and opening mode.
- A small Maia level selector next to them, showing for example "Maia 1500".
- Secondary buttons: **Custom game**, **History**, **Profile**, **Settings** and **Quit**.

### 2. First-launch name dialog
- A modal over Home with the title "What should I call you?".
- A text field prefilled with "You", and a single **OK** button. There is no skip.

### 3. Searching screen
- It appears between clicking Play and the game starting, for 0.5 s or more, like chess.com's "searching for opponent".
- One status line follows the real work: "Pausing analysis…", "Loading Maia 1500…", "Preparing game…".
- Also show the time control and the Maia level.

### 4. Game screen side panel (change only)
- **Existing panel**, top to bottom: Maia's clock, the move list (SAN), your clock and buttons.
- **New:** a **resign** button (flag) and a **draw offer** button (½) between the clocks, as on chess.com.
- **States to show:**
  - "Click again to resign": the confirm state, which lasts 2 s.
  - A brief notice, "Maia declined" or "Draw agreed".

### 5. History
- **Tabs:** All, 1+0, 3+2 and 5+0.
- **One card per game:**
  - **Thumbnail:** a small board from the player's side, at the position where the game's named opening ends, with the last move highlighted.
  - **Opening name**, only when known, for example "Caro-Kann Defense: Advance Variation". Show the name only, never the move sequence.
  - **Players:** "Bruno x Maia 1500", with a white/black colour marker for each player.
  - **Date**, **result and reason** (for example "Won on time", "Lost by checkmate", "Draw by agreement") and **number of moves**.
  - **Accuracy:** both sides' accuracy when the game has been analysed.
- **Actions per card:**
  - **Review**.
  - **Analyze**, or **Re-analyze** when the analysis is stale.
  - **Delete**, with confirmation.
  - **Copy PGN** as a small, discreet square icon button that is still easy to click.
- **Analysis states each card must show:**
  - not analysed;
  - queued;
  - analysing, with a percentage or progress bar;
  - analysed, showing both accuracies;
  - stale.
- **Multi-select:** checkboxes on the cards, with an "Analyze selected" button.
- **Per tab:** an **Analyze all** button.
- **Queue status line:** for example "Analysing 2 of 7 · Background".

### 6. Review (copy chess.com's Game Review layout)
- **Board area:**
  - The **eval bar on the left** of the board. It follows the board's orientation.
  - The board shows the classification icon on the destination square of the current move, and an arrow for the best move.
  - Navigate with ←/→ and with the move list.
- **Side panel:**
  - **Summary:** the two players, each side's accuracy, and a table counting each class per side. A small "?" next to the accuracy and the table shows a tooltip explaining how they are computed.
  - **Eval graph:** clickable; it jumps to that move.
  - **Move list:** with a classification icon on each move. A "Left repertoire" marker on the move where the player left their repertoire shows the expected move.
  - **Buttons:** Copy PGN, Open in Lichess, Rematch and New game.
- **States:**
  - **Analysing:** a progress bar, with icons and the graph filling in move by move.
  - **Done.**
  - **Not analysed:** an **Analyze** button instead of the summary.
- **Not included:** coach text and "retry".

### 7. Profile
- The player's name, editable.
- A W/D/L table per level and time control, with flag wins and flag losses.
- A small chart of the player's accuracy over time.

### 8. Repertoire screen
- **List:** the saved repertoires, with **Import PGN** and **From openings** buttons.
- **From openings:** opens a catalog picker, a tree of opening names with checkboxes (Family → Variation → Sub-variation, names only, as on Lichess), a colour choice (White/Black) and a name field.
- **Viewer:** a board beside the list, from the repertoire colour's side. Clicking a line shows its final position; ←/→ steps through the moves.

### 9. Repertoire editor
- A board where you play moves to extend a line or add branches.
- Beside it, a tree list of the branches. Right-clicking a move deletes it and everything after it.
- Save and Cancel buttons.

## Deliverable

One artboard per screen above. For history and review, show each of their states. When you're done, bring back screenshots of the chosen artboards.
