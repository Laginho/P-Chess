# Chess learning: what the evidence says about a training feature

Research pass, 2026-11-07. Context: adult club player (~1600 chess.com rapid / ~1900 lichess), plateaued.
Question: is a "mistake deck" (own mistakes → find-the-better-move drills with spaced repetition) worth building, and what else would be?

## TL;DR

- **No study tests drilling positions from your own games, with or without spaced repetition, on chess rating.** I searched for one and found none; the support is forum anecdotes and vendor blogs.
- The case for a mistake deck is **extrapolated**: from general learning science (retrieval practice, spacing, learning from corrected errors, all strong but mostly on verbal and fact material) and from expertise research saying chess skill is mostly pattern knowledge built by serious solitary study (correlational).
- The one chess-specific experiment that bears on the format (de Bruin et al. 2007, novices, one endgame) found that **predicting the move did nothing over watching; predicting plus explaining why did help.** That points to "explain, then see the engine", not a bare "guess the move" card.
- Risk specific to own-mistake decks: each card is a one-off position, so spaced repetition can teach you *that position* rather than the pattern. Mixing motif-matched positions from other games (interleaving) is what the category-learning research supports.
- Verdict: worth building only as a small variant of a **guided review** (attempt → explain → immediate engine feedback), not as a stand-alone flashcard deck. Expect no measurable rating effect you could attribute to it.

Provenance note: full text was read only for Burgoyne et al. 2019. Every other claim comes from abstracts, publisher/indexing pages, or the authors' repository records, as marked in References. Effect sizes not quoted below were not verified.

## 1. Does drilling your own mistakes work?

**Direct evidence: none.**
- No controlled study of own-mistake drills, Lichess "Learn from your mistakes", Chessable-style spaced repetition, or puzzle training on adult rating turned up. The closest chess "intervention" studies are on children/cognition (out of scope) or tiny pilots. (search result; absence of evidence, not evidence of absence)
- Lichess's own feature is described only in its blog: it replays a game's relevant mistakes as find-the-better-move prompts and reveals the answer on request [Lichess blog]. No efficacy data is published.
- Anecdotes cut both ways: forum users report rating gains from Anki-style tactic repetition; others note players solving tens of thousands of puzzles without rating gains [Lichess forum, Chess.SE; anecdotal, unverified].

**Indirect evidence for the ingredients (non-chess unless marked):**
- *Retrieval beats restudy at a delay.* Testing slowed initial learning but beat restudying on a 1-week test (Roediger & Karpicke 2006; experimental, non-chess material). Rated "high utility" across ages and tasks (Dunlosky et al. 2013, review).
- *Spacing helps, but most for recall.* Meta-analysis of 317 experiments: spacing benefits recall, and the best gap grows with how long you need to remember (Cepeda et al. 2006). The same review reports earlier syntheses finding the benefit in >80% of verbal studies but only ~1/3 of "intellectual skill" studies. Chess move choice is closer to the second.
- *Errors corrected with feedback are learned well,* especially confidently held errors ("hypercorrection") (Metcalfe 2017, review). Fits the deck: your game move was a confident error.
- *Attempting before seeing the answer helps even when the attempt fails* (Kornell, Hays & Bjork 2009; experimental; weakly associated word pairs, fictional trivia). The benefit disappeared when feedback was delayed after the attempt (Grimaldi & Karpicke 2012). → Show the engine answer right after the attempt.
- *Explaining beats predicting (chess, experimental).* Novices watching a computer play K+R vs K either observed, predicted moves, or predicted + self-explained. Only self-explanation improved principle understanding and checkmating at test; prediction alone = observation (de Bruin, Rikers & Schmidt 2007; experimental; first-year psychology students with no chess experience, a single endgame; sample size not checked). Extrapolating to a 1900 player is a stretch, but it is the only chess experiment on this format.
- *Interleaving similar categories helps discrimination.* Meta-analysis of 59 studies, g = 0.42; stronger when categories look alike and material is complex (Brunmair & Richter 2019). Interleaving painters' works beat blocking for learning styles, while learners believed the opposite (Kornell & Bjork 2008). A chess analogue: mixing "Nf5 sac works" with look-alike "Nf5 sac fails" positions. A personal mistake deck gives you singletons, not that contrast structure.

**Where the extrapolation is weakest:**
- Almost all of the above is recall of facts/words, measured within a week or two. Chess improvement means transferring a pattern to *new* positions under time pressure. No study shows spaced recall of specific positions transfers to new games.
- Your own mistakes are not a clean "weakness sample". Across millions of games, the difficulty of the position predicted blunders far better than player skill or time left (Anderson, Kleinberg & Mullainathan 2016; correlational, large sample). Many of your mistakes are just hard positions that most 1900s would also miss.

## 2. What drives chess improvement

**Pattern knowledge (theory, well supported for *describing* skill):**
- Masters recall real positions far better than novices but not random ones; skill rests on stored perceptual chunks (Chase & Simon 1973; recall experiments).
- Chunks extend to larger "templates" in long-term memory, explaining recall of several boards (Gobet & Simon 1996).
- Blitz (5 min) rating accounts for up to 81% of variance in normal rating, implying fast recognition carries most skill differences (Burns 2004; archival, three tournament samples; correlational). This is about *what skill is*, not evidence that playing blitz trains it. Search still matters: both pattern recognition and look-ahead contribute (Chabris & Hearst 2003; direction only, as summarised in Gobet's reply; original results not retrieved).
- Extra thinking time improved move quality for both experts and weaker players, on easy and hard tactical problems (Moxley et al. 2012; experimental, within-subject). A later critique notes first-move and final-move quality explained only 7.8% / 15.2% of skill variance.

**Practice type (all correlational, retrospective self-report):**
- *Serious study alone* was the strongest predictor of current and peak rating, above tournament play and formal instruction; for players ≥40 it was the only significant predictor (Charness et al. 2005; N = 229 + 180). Grandmasters reported ~5,000 hours of serious study in their first decade of play.
- Reanalysis of the same data (full text read): study time, private and group instruction explained 41.5% of peak-rating variance; **tournament play added only ΔR² = .006** (p = .049) on top. A model with serious-activity and instruction factors plus starting age explained 63.4% (Burgoyne et al. 2019; N = 377). Recall check in the original: diary vs estimate r = .74.
- Conflicting result: in 104 Argentine players, **group practice (including tournament games) predicted high-level skill better than individual practice**, and masters out-rated experts after ~3 years of serious play despite similar hours (Gobet & Campitelli 2007; Campitelli & Gobet 2008). The two datasets do not settle which practice mode matters more.
- Deliberate practice explains ~34% of chess skill variance after correction (Hambrick et al. 2014, meta-analysis of chess studies); games 26% in an 88-study cross-domain meta-analysis (Macnamara et al. 2014). Practice is necessary, not sufficient; the rest is unexplained or other factors (starting age r ≈ −.40 controlling hours, Gobet & Campitelli 2007).
- None of these studies isolates **analysing your own games**, **tactics puzzles**, or **slow vs fast games** as separate predictors. Any claim that one of these is "the" lever is not backed by this literature.

**Not relevant:** the Sala & Gobet transfer meta-analyses (2016/2017) cover chess → school/cognitive skills, not chess improvement; not cited further.

**Maia (relevant as a tool, not as learning evidence):** Maia models trained on human Lichess games at fixed ratings (1100–1900) predict human moves better than Stockfish or Leela and can predict whether a human will blunder (McIlroy-Young et al. 2020, KDD). Fine-tuned per-player models add ~4–5 points of move-matching accuracy but needed ~5,000 games per player (McIlroy-Young et al. 2022, KDD). No published study uses Maia for training a human.

## 3. Implications for P-Chess

Already there: Maia bots at set ratings, Stockfish review with classification and accuracy, history, repertoire, side lines with live engine.

Design rules the evidence supports (strength in brackets):
1. **Attempt, then explain, then see the engine immediately** [chess experiment on novices + general experiments]. Don't let the user see the eval bar or classification first; don't delay feedback after the attempt.
2. **Slow down at critical moments** [Moxley 2012]. Give untimed thinking at drill/review positions.
3. **Feed the learner patterns, not just positions** [interleaving meta-analysis; chunking theory]. Pair each own mistake with similar positions from other games.
4. **Filter which mistakes become drills** [Anderson 2016]. Skip positions that are hard for everyone at the user's level; Lichess already filters by winning-chance change rather than raw centipawns [Lichess blog/forum]. Maia's "would a 1900 play this?" probability is a usable proxy for "instructive for you" (not validated).
5. **Expect to be unable to tell whether it worked** [no direct evidence]. Logging per-card success rates is cheap; rating change won't be attributable.

## Ranked features (by evidence class, then cost given what exists)

Evidence class: (a) chess-specific experiment, (b) general learning-science experiments, (c) correlational only, (d) none.

1. **Guided slow-game review: user annotates and explains their candidate moves before the engine is revealed** — (a)+(b): only option with a chess experiment behind it (self-explanation, de Bruin 2007), plus attempt-before-feedback (Kornell 2009) and corrected-error learning (Metcalfe 2017); cheap since review board and engine exist.
2. **Mistake drill as an extension of #1, not a separate deck**: each lesson-worthy mistake becomes "find the move + say why", answer shown immediately, re-shown spaced — (b): retrieval + spacing + hypercorrection, but on one-off positions and with no transfer evidence; keep the queue small and retire cards fast.
3. **Motif-matched practice**: for each mistake, pull 3–5 positions with the same theme from a puzzle database and interleave them — (b): interleaving g = 0.42 is strongest for look-alike categories (Brunmair & Richter 2019), chunking theory says skill is pattern breadth; needs a tagged puzzle source (e.g. database.lichess.org; licence not checked).
4. **Play out the critical position vs Maia at your rating** (from just before the mistake) — (c)/(d): games are a weak predictor beyond study (ΔR² = .006) and Maia's training value is untested, but it is cheap with existing bots and adds the "does it work against a human-like reply" check that puzzles lack.
5. **Repertoire drill (spaced recall of your lines)** — (b) but low value: spacing/retrieval evidence fits memorised sequences best (Cepeda 2006 verbal recall), yet no study ties opening memorisation to rating at 1600–1900.
6. **Mistake breakdown by phase / clock / colour** — (d) as training; descriptive only. Useful to choose what to study, but Anderson 2016 says difficulty dominates, so raw counts by phase will mostly reflect which phases have hard positions. Include a "% of mistakes made with <X seconds" stat if built; time trouble is the one actionable pattern it would surface.

Not recommended as features: "play more blitz" (Burns 2004 is about measuring skill, not training it); pure eval-bar replay without an attempt step (prediction-free observation was the weakest condition in de Bruin 2007).

## References

Status key: **[full]** full text read; **[abs]** abstract / publisher or index page only; **[sec]** secondary source only.

- Anderson, A., Kleinberg, J., & Mullainathan, S. (2016). Assessing human error against a benchmark of perfection. *KDD 2016*; ACM TKDD 2017. arXiv:1606.04956. https://arxiv.org/abs/1606.04956 **[abs]** (accuracy figures for skill/time/difficulty from a secondary note, not quoted above)
- Brunmair, M., & Richter, T. (2019). Similarity matters: A meta-analysis of interleaved learning and its moderators. *Psychological Bulletin*, 145(11), 1029–1052. https://doi.org/10.1037/bul0000209 **[abs]**
- Burgoyne, A. P., Nye, C. D., Macnamara, B. N., Charness, N., & Hambrick, D. Z. (2019). The impact of domain-specific experience on chess skill: Reanalysis of a key study. *American Journal of Psychology*, 132(1), 27–38. https://doi.org/10.5406/amerjpsyc.132.1.0027 **[full]**
- Burns, B. D. (2004). The effects of speed on skilled chess performance. *Psychological Science*, 15(7), 442–447. https://doi.org/10.1111/j.0956-7976.2004.00699.x **[abs]**
- Campitelli, G., & Gobet, F. (2008). The role of practice in chess: A longitudinal study. *Learning and Individual Differences*, 18(4), 446–458. https://researchportal.murdoch.edu.au/esploro/outputs/journalArticle/The-role-of-practice-in-chess/991005542731507891 **[abs]**
- Cepeda, N. J., Pashler, H., Vul, E., Wixted, J. T., & Rohrer, D. (2006). Distributed practice in verbal recall tasks: A review and quantitative synthesis. *Psychological Bulletin*, 132(3), 354–380. https://doi.org/10.1037/0033-2909.132.3.354 **[abs]**
- Chabris, C. F., & Hearst, E. S. (2003). Visualization, pattern recognition, and forward search: Effects of playing speed and sight of the position on grandmaster chess errors. *Cognitive Science*, 27, 637–648. **[sec]** via Gobet's reply, https://bura.brunel.ac.uk/handle/2438/1391
- Charness, N., Tuffiash, M., Krampe, R., Reingold, E., & Vasyukova, E. (2005). The role of deliberate practice in chess expertise. *Applied Cognitive Psychology*, 19(2), 151–165. https://doi.org/10.1002/acp.1106 **[abs]** + sample details from Burgoyne 2019 **[full]**
- Chase, W. G., & Simon, H. A. (1973). Perception in chess. *Cognitive Psychology*, 4(1), 55–81. https://doi.org/10.1016/0010-0285(73)90004-2 **[abs]** (DOI inferred from ScienceDirect PII)
- de Bruin, A. B. H., Rikers, R. M. J. P., & Schmidt, H. G. (2007). The effect of self-explanation and prediction on the development of principled understanding of chess in novices. *Contemporary Educational Psychology*, 32(2), 188–205. https://repub.eur.nl/pub/66197 **[abs]**; full text as ch. 4 of de Bruin's dissertation, https://repub.eur.nl/pub/8144 (not read)
- Dunlosky, J., Rawson, K. A., Marsh, E. J., Nathan, M. J., & Willingham, D. T. (2013). Improving students' learning with effective learning techniques. *Psychological Science in the Public Interest*, 14(1), 4–58. https://doi.org/10.1177/1529100612453266 **[abs]**
- Ericsson, K. A., Krampe, R. T., & Tesch-Römer, C. (1993). The role of deliberate practice in the acquisition of expert performance. *Psychological Review*, 100(3), 363–406. https://doi.org/10.1037/0033-295X.100.3.363 (background; cited by Burgoyne 2019)
- Gobet, F., & Campitelli, G. (2007). The role of domain-specific practice, handedness, and starting age in chess. *Developmental Psychology*, 43(1), 159–172. https://doi.org/10.1037/0012-1649.43.1.159 **[abs]**
- Gobet, F., & Simon, H. A. (1996). Templates in chess memory: A mechanism for recalling several boards. *Cognitive Psychology*, 31(1), 1–40. https://doi.org/10.1006/cogp.1996.0011 **[abs]**
- Grimaldi, P. J., & Karpicke, J. D. (2012). When and why do retrieval attempts enhance subsequent encoding? *Memory & Cognition*. https://learninglab.psych.purdue.edu/downloads/2012/2012_Grimaldi_Karpicke_MC.pdf **[sec]**
- Hambrick, D. Z., Oswald, F. L., Altmann, E. M., Meinz, E. J., Gobet, F., & Campitelli, G. (2014). Deliberate practice: Is that all it takes to become an expert? *Intelligence*, 45, 34–45. https://doi.org/10.1016/j.intell.2013.04.001 **[abs]**
- Kornell, N., & Bjork, R. A. (2008). Learning concepts and categories: Is spacing the "enemy of induction"? *Psychological Science*, 19(6), 585–592. https://doi.org/10.1111/j.1467-9280.2008.02127.x **[abs]**
- Kornell, N., Hays, M. J., & Bjork, R. A. (2009). Unsuccessful retrieval attempts enhance subsequent learning. *JEP: Learning, Memory, and Cognition*, 35(4), 989–998. https://pubmed.ncbi.nlm.nih.gov/19586265/ **[abs]**
- Lichess. "Learn from your mistakes" (blog announcement). https://lichess.org/blog/WFvLpiQAACMA8e9D/learn-from-your-mistakes **[official blog]**; mistake-filtering by winning chances per Lichess forum replies **[sec]**
- McIlroy-Young, R., Sen, S., Kleinberg, J., & Anderson, A. (2020). Aligning superhuman AI with human behavior: Chess as a model system. *KDD 2020*. https://arxiv.org/abs/2006.01855 **[abs]**
- McIlroy-Young, R., Wang, R., Sen, S., Kleinberg, J., & Anderson, A. (2022). Learning models of individual behavior in chess. *KDD 2022*. https://doi.org/10.1145/3534678.3539367 **[abs]**; 5,000-games figure from a 2025 follow-up, arXiv:2507.21488 **[sec]**
- Macnamara, B. N., Hambrick, D. Z., & Oswald, F. L. (2014). Meta-analysis of deliberate practice across domains (88 studies). **[sec]** via Hambrick et al. 2014 commentary results; venue not checked.
- Metcalfe, J. (2017). Learning from errors. *Annual Review of Psychology*, 68, 465–489. https://doi.org/10.1146/annurev-psych-010416-044022 **[abs]**
- Moxley, J. H., Ericsson, K. A., Charness, N., & Krampe, R. T. (2012). The role of intuition and deliberative thinking in experts' superior tactical decision-making. *Cognition*, 124(1), 72–78. https://doi.org/10.1016/j.cognition.2012.03.005 **[abs]**; variance critique from a 2023 *Psychological Research* paper, https://doi.org/10.1007/s00426-023-01823-x **[sec]**
- Roediger, H. L., & Karpicke, J. D. (2006). Test-enhanced learning: Taking memory tests improves long-term retention. *Psychological Science*, 17(3), 249–255. https://doi.org/10.1111/j.1467-9280.2006.01693.x **[abs]**
- Anecdotal, not evidence: Lichess forum "Much needed – Spaced Repetition Tactics", https://lichess.org/forum/lichess-feedback/much-needed---spaced-repetition-tactics; Chess StackExchange thread on SRS for tactics (via Scribd copy). **[anecdote]**
- Tangential: Narayanan, S., Panjwani, R., Sen, S., & Ho, C.-J. (2026). Improving human performance with value-aware interventions: A case study in chess. arXiv:2604.14465 **[abs]**. In-game move overrides, N = 20, not training; not used above.
