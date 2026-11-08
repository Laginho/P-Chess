# P-Chess

A Windows chess app that teaches by stages: a course set by your rating, play-outs against Maia, a human-like bot, and a sandbox for fast games, all in one place.

## Course

**Course**:
Everything the app teaches, split into stages by rating. You only see your own stage.
_Avoid_: curriculum, lessons, programme

**Rating**:
Your rapid rating on chess.com or Lichess, as you state it in the rating sentence. Always shown on the chess.com scale.
_Avoid_: Elo, level, strength

**Stage**:
The slice of the course for one rating band. Your rating picks it.
_Avoid_: tier, band, level

**Unit**:
One topic inside a stage (the first is rook endgames), made of four parts.
_Avoid_: lesson, chapter, module

**Part**:
One of a unit's four steps, in order: theory pointer, solving, play-outs, pass test. Nothing is locked; any part opens from the unit page.
_Avoid_: step, section

**Theory pointer**:
The part that sends you to read elsewhere: a goal line, search terms and book chapters. It holds no explanation of its own.
_Avoid_: lesson, theory, reading

**Continue**:
The one button that picks your next thing to do: a due review check, then positions from your own games, then the next unfinished part, then the next unit.
_Avoid_: resume, next, recommended

## Solving

**Position**:
A setup you solve by entering a line, with the side you play and how many of your moves the line needs.
_Avoid_: puzzle, exercise, problem

**Line**:
The moves you enter for a position, yours and the opponent's, before you commit.
_Avoid_: answer, solution, variation

**Commit**:
Sending your line to be graded. Only the first commit of a position can count as first try.
_Avoid_: submit, check

**Solved**:
A position whose committed line kept the result at every one of your moves without a slow detour.
_Avoid_: correct, passed

**First try**:
Solved on the first commit. The first-try rate is shown apart from the solved count.
_Avoid_: first attempt, clean solve

**From your game**:
A position taken from one of your reviewed games, at the move where you changed the result. It joins the unit's positions.
_Avoid_: personal puzzle, your mistake, own-game card

## Play-outs and the test

**Play-out**:
Playing a position to the end against an opponent, either to convert or to hold.
_Avoid_: drill, sparring, practice game

**Convert**:
A play-out where you have the winning side: you pass by promoting or mating.
_Avoid_: win drill

**Hold**:
A play-out where you defend: you pass when the pawn is gone or after enough moves held.
_Avoid_: defend drill, save

**Perfect opponent**:
The tablebase-backed engine used in the pass test's play-outs, which never misses a defence or a win.
_Avoid_: Stockfish (as a role name), max level

**Pass test**:
The last part: unseen positions plus one convert and one hold against the perfect opponent. Passing it masters the unit.
_Avoid_: exam, quiz, final

## Unit status

**Unit status**:
Where a unit stands for you: new, in progress, mastered or needs review.

**Mastered**:
The status a unit gets when you pass its test. The badge stays even if a later review check is missed.
_Avoid_: complete, finished, done

**Review check**:
A short set of positions that Continue offers 7 and 30 days after a unit is mastered.
_Avoid_: spaced repetition, refresher, quiz

**Needs review**:
The status of a mastered unit whose review check was missed.
_Avoid_: failed, expired, rusty

## Play

**Sandbox**:
Quick games against Maia at 1+0, 3+2 or 5+0, outside the course.
_Avoid_: quick play (in prose), free play, casual mode

**Maia level**:
The strength Maia plays at, named after its net ("Maia 1500"). In the course it follows your rating; in the sandbox you pick it.
_Avoid_: difficulty, bot rating
