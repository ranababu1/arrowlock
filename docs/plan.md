# Arrowlock: Product and Engineering Plan

**Document status:** Original project baseline  
**Product type:** Single-player directional escape puzzle  
**Initial platform:** Android  
**Default engine direction:** Godot 4.x + GDScript, subject to toolchain verification  
**Planning principle:** Validate a small, polished puzzle loop before expanding content or monetization.

## 1. Product vision and target audience

Arrowlock is a tactile logic puzzle in which players clear a board by tapping directional arrows. An arrow may leave only when its path to the board edge is clear. The satisfaction comes from reading the board, planning an order, and watching a clean sequence of removals.

Primary audience:
- Casual puzzle players who enjoy short, self-contained logic problems.
- Mobile players looking for 1 to 5 minute sessions.
- Players who prefer clear rules and thoughtful challenge over reflex-heavy play.

Secondary audience: players who enjoy increasingly complex rule combinations and shareable puzzle results.

Product promise: “See the path. Find the order. Clear the board.” Avoid claims that the game is uniquely viral or universally accessible until tested.

## 2. Core gameplay loop and mechanics

1. Present a board containing arrows with fixed directions.
2. Player taps an arrow.
3. The rules engine checks whether the arrow's forward path to the board boundary is unobstructed by other arrows.
4. If clear, remove the arrow with a short animation and update the board state.
5. If blocked, provide a restrained, understandable feedback cue without punishing experimentation in the MVP.
6. Continue until all arrows are removed or the player uses restart/undo.
7. Award completion and optional efficiency rating; unlock the next puzzle.

MVP rules:
- Orthogonal directions: up, down, left, right.
- Each arrow occupies one grid cell and has one direction.
- An arrow is blocked if another remaining arrow occupies any cell along its ray before the board boundary.
- A clear arrow can be removed with one tap.
- Completion occurs when no arrows remain.
- A puzzle is valid only if every arrow can be removed in at least one valid sequence.

Future mechanics, not MVP:
- **Locked arrows:** require a key, color condition, or prerequisite.
- **Rotating arrows:** change direction after a defined event or tap.
- **Chain reactions:** removing an arrow triggers a predictable set of removals.
- Diagonal arrows, portals, moving obstacles, timed modes, and user-generated levels.

## 3. Unique selling proposition and differentiation

The baseline mechanic is familiar to directional escape puzzles, so differentiation must be earned through execution:
- Readable, uncluttered boards with satisfying but brief removal feedback.
- Strong puzzle craftsmanship, verified solvability, and fair difficulty ramps.
- Optional “clean solve” or efficiency medals that reward planning without making the basic game stressful.
- Later, a daily board with a reproducible seed and shareable result card.

Do not rely on a large feature list as differentiation. Validate whether players perceive the puzzle, presentation, or daily challenge as distinctive.

## 4. MVP scope and explicit exclusions

### Included
- Portrait-first Android game.
- Main menu, level selection/progression, puzzle screen, pause/settings.
- A small curated pack of approximately 40 levels, with level count adjusted after production testing.
- Deterministic board representation and move-validation engine.
- Undo or restart; choose undo for forgiving experimentation if implementation remains simple.
- Local progress and settings persistence.
- Tutorial levels introducing ray blocking.
- Basic audio/haptics controls if reliable on target devices.
- Offline-first operation.
- Lightweight, privacy-conscious event measurement only after consent/disclosure and platform requirements are resolved.

### Excluded
- Accounts, cloud saves, multiplayer, chat, social graph, user-generated levels.
- Ads, in-app purchases, subscriptions, paid level packs in the first validation build.
- Locked, rotating, and chain-reaction mechanics.
- Online leaderboards and a custom backend.
- Procedural levels in the player-facing MVP unless generator validation is complete.
- Any claim of guaranteed viral growth.

## 5. Progression and difficulty balancing

Use curated levels initially. Increase one dimension at a time:
1. Small boards with obvious exits.
2. More arrows and longer dependency chains.
3. Multiple possible first moves, but one clear intended route.
4. Dense layouts requiring planning several moves ahead.
5. Optional expert levels with efficiency targets.

Difficulty variables: grid dimensions, arrow count, longest dependency chain, number of legal first moves, number of plausible but suboptimal moves, and estimated solution depth. Do not equate arrow count alone with difficulty.

Level validation:
- Model the board as a deterministic state.
- Generate or author a candidate level.
- Run a solver/search over legal removals to prove at least one solution exists.
- Reject or flag levels that exceed a reasonable solver budget.
- Store a reference solution and expected minimum moves when known.
- Use a separate solver implementation or independent verification path where feasible to reduce correlated bugs.

Balancing procedure:
- Track completion rate, median solve time, restart rate, undo usage, and exit rate by level.
- Flag levels with unexpectedly low completion or unusually high abandonment.
- Adjust in small batches, not from one player's result.
- Ensure tutorial levels have near-universal completion in moderated tests before adding complex mechanics.

## 6. Technical architecture and recommended stack

### Default
- Godot 4.x stable release and GDScript.
- Android export templates matching the chosen Godot version.
- Native Godot UI and 2D rendering; no external game framework.
- Git repository with source assets and reproducible export instructions.

### Suggested modules
- `BoardState`: dimensions, arrow IDs, positions, directions, remaining arrows.
- `MoveValidator`: ray-cast occupancy and legal-removal checks.
- `PuzzleSolver`: offline/editor/test utility for solvability and reference solutions.
- `PuzzleRepository`: loads curated level data and metadata.
- `ProgressService`: completed levels, best score/time, settings.
- `SaveService`: versioned local save schema and safe fallback on invalid data.
- `GameController`: coordinates selection, state transitions, animation requests.
- `HUD` / scenes: presentation and input only; must not own puzzle rules.

Use stable arrow IDs rather than relying on scene-node order. Keep the model deterministic. Persist progress locally; do not add a backend for MVP.

### Level data
Store levels as versioned resources or JSON files checked into source control. Validate schema on load. Do not treat untrusted level data as executable code.

### Performance
The board is small, so optimize for correctness and responsiveness rather than premature low-level optimization. Keep logic operations cheap and avoid frame-blocking solver work at runtime. Solver-heavy validation should run in editor tooling or automated tests.

## 7. UI/UX and visual direction

- Portrait-first, calm and premium puzzle-board presentation.
- High-contrast arrows and clear directional silhouettes; color must not be the only cue.
- Large touch targets with safe spacing; provide immediate blocked/available feedback.
- Keep the board visually dominant and minimize persistent UI.
- Use brief removal animations and optional subtle haptics; provide settings to reduce or disable effects where appropriate.
- Avoid visual clutter, excessive particles, intrusive popups, and forced tutorial text walls.
- Support common Android aspect ratios and system insets.
- Ensure text readability, contrast, and color-blind resilience.
- Tutorial: demonstrate one rule at a time and allow the player to act immediately.

## 8. AI-assisted development opportunities

Good uses:
- Generate candidate level layouts, then run the deterministic solver and human review.
- Draft GDScript tests for edge cases, with a developer verifying test quality.
- Produce placeholder icons, sound concepts, and level-design variations under a consistent art direction.
- Analyze anonymized aggregate play-test metrics for difficulty outliers.
- Assist with code review and documentation updates.

Guardrails:
- AI-generated puzzles are not accepted without solvability checks and play-testing.
- AI-generated code must be reviewed, tested, and integrated in small buildable increments.
- Do not upload signing keys, credentials, private player data, or secrets to AI tools.
- Do not use AI-generated art/audio without confirming commercial usage rights and store disclosure implications.

## 9. Monetization strategy

Validation phase: no monetization. Establish that the core loop is enjoyable and retention is plausible before adding friction.

Possible later tests:
- Rewarded ad for an optional hint or undo refill, never required to finish a level.
- One-time purchase to remove ads or unlock a curated premium pack.
- Optional cosmetic arrow themes.

Do not introduce interstitials between every level. Measure ad impact on session length, reviews, retention, and revenue per user. Monetization is a hypothesis, not a commitment.

## 10. Analytics, retention, and viral growth

Use minimal event names and avoid collecting personal data:
- `tutorial_started`, `tutorial_completed`
- `level_started`, `level_completed`
- `level_failed_or_stuck` only if failure is defined; otherwise track restarts/undo.
- `level_duration_bucket`, `restart_used`, `undo_used`
- `daily_puzzle_started/completed` only in a later milestone
- `share_sheet_opened`, `share_completed_if_observable`

Do not infer a share was successful if Android does not expose that outcome. Prefer aggregate, privacy-reviewed analytics. A local-only prototype can begin with opt-in play-test logs and no SDK.

Validation funnel:
- Store listing conversion = installs / store listing visitors.
- Tutorial completion = tutorial completers / tutorial starters.
- D1 and D7 retention = users returning on day 1/day 7 under a documented analytics definition.
- Engagement = sessions per active user, median session length, puzzles completed per session.
- Sharing = share actions per eligible active user and attributed referrals where attribution is lawful and technically reliable.

Proposed initial decision gates, treated as hypotheses:
- Tutorial completion at least 80% in a small usability cohort.
- D1 retention target at least 25% and D7 at least 8% after enough installs to reduce noise.
- Store listing conversion target at least 20%, interpreted against traffic source and benchmark context.
- Do not declare success from a tiny sample. Report sample size and uncertainty.

Growth experiments:
1. Test 2 to 3 store-icon and screenshot concepts with equivalent traffic.
2. Compare concise puzzle-focused listing copy against a challenge-focused variant.
3. Test a spoiler-free share card after daily puzzles exist.
4. Compare optional hint framing without paywalling basic completion.

## 11. Development milestones and acceptance criteria

### M0: Technical spike
- Godot project opens and exports to a test Android device.
- Touch input and portrait layout work on at least one physical device.
- Git ignore and repeatable build notes exist.

### M1: Rules engine
- Unit tests cover each direction, edge exits, blockers, multiple blockers, empty board, invalid coordinates, and removal state.
- Legal move results are deterministic.
- A simple authored board can be completed without rendering dependencies.

### M2: Puzzle screen
- Player can select and remove legal arrows.
- Blocked moves have clear feedback.
- Completion is detected exactly once.
- Restart/undo behaves correctly.

### M3: Progress and content
- Initial curated levels load with schema validation.
- All included levels pass automated solvability checks.
- Progress survives app restart and invalid save data fails safely.

### M4: Usability polish
- Tutorial can be completed without verbal explanation in moderated tests.
- Touch targets, contrast, system insets, pause/resume, and audio settings are checked.
- No known blocker prevents a clean play-through.

### M5: Closed test
- Test on a small set of Android devices and screen sizes.
- No unresolved data-loss, progression-lock, or crash-on-start issue.
- Collect store-funnel, tutorial, retention, and engagement data with a documented privacy approach.

### M6: Release candidate
- Release build installs cleanly and upgrades from the previous test build.
- App content, privacy policy, Data safety, content rating, permissions, and store assets are reviewed.
- Version code, release notes, commit, and test evidence are recorded.

## 12. Risks, assumptions, and validation experiments

Risks:
- Familiar mechanic may not stand out in a crowded puzzle category.
- Incorrectly authored levels can cause soft locks or frustration.
- Too many mechanics too early can obscure the core rule.
- Ad monetization can harm the calm puzzle experience.
- Device layout variations can make dense boards hard to use.

Assumptions to validate:
- Players understand ray blocking quickly.
- Curated levels sustain interest for multiple sessions.
- Optional efficiency medals add replay value rather than pressure.
- Daily seeded puzzles motivate return visits.

Experiments:
- Five-player think-aloud test for the first 10 levels.
- Compare level completion and restart patterns for two board-size curves.
- Run a solver against every authored level in CI or the content-validation command.
- Test daily challenge cards only after the core puzzle is validated.

## 13. Google Play release strategy

1. Confirm current Play Console requirements and target API deadline before submission; requirements change over time.
2. Prepare app icon, phone screenshots, short/full descriptions, feature graphic if required, privacy policy, Data safety, content rating, ads declaration, and support contact.
3. Use internal testing first, then closed testing. Meet any account-specific testing requirements shown by Play Console.
4. Test install, update, offline play, app pause/resume, and save persistence on physical devices.
5. Use Android App Bundle for Play distribution unless current platform guidance requires otherwise.
6. Protect signing keys and use Play App Signing where appropriate.
7. Roll out gradually when available, monitor crashes/ANRs, reviews, conversion, tutorial completion, D1/D7 retention, and level-specific abandonment.
8. Do not use misleading screenshots, fabricated ratings, incentivized reviews, or unsupported claims.
9. Treat production release as an explicit owner-approved milestone.
