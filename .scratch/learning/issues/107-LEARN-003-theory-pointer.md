# LEARN-003: Theory pointer
Stage: done
Blocked by: LEARN-002
Review: agent
Difficulty: normal

- Primary files:
  - core/course.gd (recording that the theory pointer was opened)
  - New: ui/theory_pointer.gd, ui/theory_pointer.tscn
  - ui/main.gd (opening it from the unit page's part request)
  - tests/test_course.gd
  - tests/test_course_screens.gd
  - scripts/screens.gd (`BOARDS`: Theory)

#### What to build

The first part of a unit only points elsewhere (design `Theory.dc.html`, CONTEXT "Theory pointer"): the goal line, the search terms as buttons that copy themselves, the books with their chapters, and "Read up, then come back.", with Back to the unit and Next: Solving. Opening it marks the part done.

#### Acceptance criteria

1. The screen shows the unit's goal, search terms and any books with chapters from the unit file, and no other explanatory text. LEARN-004 supplies the real unit's 1–2 books and chapters; until then, hide the empty books section.
2. Clicking a search term copies it to the clipboard.
3. Opening the screen marks the theory pointer done in `user://course.json`; the unit page then shows it done and moves Continue to the next part.
4. Back to the unit returns to the unit page; Next: Solving emits the solving part request.

#### Verification

    godot --headless -s tests/run.gd

## Tests stage 2 writes (own commit, red)

- `tests/test_course.gd`: recording the theory pointer marks it done (red: no function).
- `tests/test_course_screens.gd`: opening the theory pointer from the unit page shows the fixture's terms and marks it done; clicking a term puts it on the clipboard (red: no screen).

## Comments

- 2026-11-07 Written from `.scratch/learning/spec.md` §L1, §L11.

- Proxy decided (opus-5.5 xhigh): LEARN-003 adds no book or chapter entries. Criterion 1 is met by showing the books and chapters the unit file holds, and the real books come in LEARN-004 — that ticket already owns them, and neither of us can confirm the chapter titles or numbers. (receipt /tmp/sweatshop-proxy/20261108-004319-LEARN-003-ca1693.json)
- LEARN-004 criterion 5 owns the checked book chapters and human content review. Until then, the released unit displays its goal and terms without a books section; integration is unaffected.

- Criteria check (independent agent): ✅ 1 — `ui/theory_pointer.gd:21` and `ui/theory_pointer.gd:41`; `tests/test_course_screens.gd` checks the goal, terms, visible book entries and empty state under the proxy-adjusted contract.
- Criteria check (independent agent): ✅ 2 — `ui/theory_pointer.gd:35`; clipboard assertion passed on Xvfb and failed when the copied term was mutated.
- Criteria check (independent agent): ✅ 3 — `core/course.gd:197`, `ui/theory_pointer.gd:61`, `ui/main.gd:501`; course and screen tests verify persisted completion and Continue.
- Criteria check (independent agent): ✅ 4 — `ui/theory_pointer.gd:10`, `ui/main.gd:224`; screen test exercises both Back controls and the solving request.
- Harness correction: the headless display cannot read the clipboard; the clipboard assertion runs on a supported display. Xvfb run: 5 passed, 0 failed; mutation to a wrong copied term failed as expected. The old `test_course_navigation_unit_progress_and_clock` now returns from the newly implemented theory screen before continuing its existing navigation assertions.
- Layout and book visibility tests failed before the fixes and passed afterward; a mutation hiding populated books also failed as expected. A 1280 × 800 Xvfb capture was inspected.

## Resolution

Implemented the theory pointer, copying search terms, completion persistence and unit/solving navigation. The real unit's books remain LEARN-004 content; the empty section stays hidden until then. `godot --headless -s tests/run.gd`: 593 passed, 0 failed. Clipboard checked separately with Xvfb: 5 passed, 0 failed.

Gate evidence: /tmp/learn003-gate.json

#### Resolution (2026-11-08)
Verdict: Approve

Reviewed the complete eight-file diff `bda50d5...7913ee1` and all nine commits with independent read-only Standards and Spec reviewers `/root/standards_review` and `/root/spec_review`. Neither the closing reviewer nor the independent reviewers authored production changes. All four numbered criteria pass; no behavior repair or new contract decision was needed.

- Standards: 0 documented violations and 0 new actionable findings from the independent review. Primary-file scope, domain vocabulary, scene ownership and test/production commit separation are intact. The closing reviewer noted that `open_theory()` repeats the existing progress persistence sequence; [CLEAN-017](116-CLEAN-017-shared-course-persistence.md) now records this third caller for its optional cleanup triage. This is a maintenance observation, not a criterion failure.
- Spec: 0 findings, missing criteria, scope creep or confirmed regressions.
- ✅ 1: `ui/theory_pointer.gd:21–60` reads the selected unit's goal, search terms, book titles and chapters, and hides the empty books card. `test_theory_pointer_displays_data_copies_and_navigates` checks a fixture with three distinct terms and two books/chapters; `test_course_navigation_unit_progress_and_clock` checks that the shipped empty books section stays hidden. The screen adds no instructional explanation.
- ✅ 2: `ui/theory_pointer.gd:35` copies the selected term. The screen test checks the second term on displays supporting the clipboard. Its Xvfb run passed all 5 screen tests, while a mutation copying `wrong term` failed with the expected clipboard mismatch.
- ✅ 3: `ui/theory_pointer.gd:61` calls `core/course.gd:197–226` to record completion. The logic test reloads progress and confirms theory completion, preserved rating, solved work and another unit's progress, then confirms corrupt JSON is not overwritten. The screen test verifies persisted completion, the unit's Done label and Continue moving to solving.
- ✅ 4: `ui/theory_pointer.gd:10–12` wires both Back controls and Next. `ui/main.gd:224–227,501–510` returns to the selected unit and forwards the solving part request. The screen test exercises both Back controls and checks the theory/solving requests in order. Solving's screen remains subsequent ticket work, as the criterion requires only the request.

Affected callers, failure paths and cross-feature interactions examined: Home → course map → unit → theory entry; repeated presentation and rebuilding term/book controls; both Back actions; Next request forwarding; return through map to Home; unit status/Continue updates; clock-choice preservation; settings shortcut coverage; screenshot registration and Theory dispatch; invalid unit IDs, malformed theory arrays, unreadable/corrupt progress, and temporary-file write/flush/rename failure handling. The save-error message and storage failure branches were inspected statically. Not exercised here: native Windows clipboard, physical pointer/keyboard input, actual disk-full or rename faults, alternate window sizes, or live Lc0. Inspected the existing [1280×800 capture](</run/media/lage/New Volume/Scratch/learn003-capture/Theory.png>): goal, terms, footer and navigation are visible, with the empty books card absent.

Red/green proof: `727c4a9` → `c8fcec0` covers persisted theory opening (red: missing public method; green: 11 course tests); `82e1958` → `58b354d` covers entry/navigation (red: missing theory screen). The headless clipboard assertion initially failed because that display cannot read the clipboard; test-only correction `bee9eca` retains the assertion on supported displays, verified by the Xvfb wrong-term mutation. `55b553f` → `f1b75fd` covers the zero-height content viewport and empty books card (red: both assertions fail; green: 5 screen tests). Test-only strengthening `0f84421` catches a mutation hiding populated books (red: visible-card assertion fails; restored code: 5 screen tests pass). Each commit keeps production separate from tests; the existing navigation test adjustment returns from the newly implemented screen while retaining its earlier request assertions. Evidence: [persistence red](/tmp/learn003-red1.log), [screen red](/tmp/learn003-red2.log), [layout red](/tmp/learn003-red3.log), [clipboard red](/tmp/learn003-clipboard-red.log), [clipboard green](/tmp/learn003-clipboard-green.log), [books red](/tmp/learn003-books-red.log), [books green](/tmp/learn003-books-green.log).

Gate: reused `godot --headless -s tests/run.gd` at `0f84421b1142a972cb76a4e0fd2a7d63fd6a11c0`: 593 passed, 0 failed, exit 0. The official `Assert-GateEvidence` helper validated the [receipt](/tmp/learn003-gate.json), command, log hash, exit marker and identical tested code before and after integration. The existing suite skips one graphical pixel check and six live Lc0 checks; clipboard behavior is covered separately by the 5-test Xvfb run. `git diff --check` passed. Rebase was a no-op and review changed only tracker metadata, so no full gate rerun was needed.

Delivery: integrated into `sweatshop/learning/2026-11-07-2234` with merge commit `c9b0740`. This closing commit records `Stage: done` and its ledger entry together. No PR or push was performed in the session flow.

Proxy disclosure: the existing `Proxy decided (opus-5.5 xhigh)` line was checked against [its receipt](/tmp/sweatshop-proxy/20261108-004319-LEARN-003-ca1693.json). It assigns checked real book/chapter content to LEARN-004 criterion 5 and keeps the books section hidden until content exists. The proxy's recorded decision and current criterion 1 agree. Integration is unaffected; complete the content and its human review before release. No new proxy call or contract change was made during review.

Acceptance: passed | Automated persistence and Main-scene navigation/content tests, the supported-display clipboard run with mutation proof, and the inspected 1280×800 capture support all four ticket criteria. Native Windows clipboard behavior has not been exercised.
Disclosure: decision | release | [Existing proxy decision](/tmp/sweatshop-proxy/20261108-004319-LEARN-003-ca1693.json) and [LEARN-004 criterion 5](108-LEARN-004-rook-endgames-content.md): real books and checked chapters remain content work requiring human review; their absence does not block this screen's integration.
Disclosure: deferred | none | [CLEAN-017](116-CLEAN-017-shared-course-persistence.md) tracks the repeated persistence sequence, including `open_theory()`, as optional maintenance without an integration or release condition.
