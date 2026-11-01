# Level Plan: 500 Levels (proposal)

**Status:** Proposal, awaiting owner approval. `plan.md` scopes about 40 curated levels and excludes player-facing procedural levels "unless generator validation is complete". This document proposes a departure from that baseline and changes nothing in `plan.md`.

## 1. A constraint that shapes everything

With the MVP rules, removing an arrow can only unblock others, never block them. Consequences:

- A board is solvable if and only if its blocking graph has no cycle. No order of legal removals can get stuck.
- Every solution takes exactly N moves for N arrows, so "minimum moves" and "efficiency medals" from `plan.md` carry no information.
- There are no "plausible but suboptimal moves". Difficulty can only come from how hard a board is to read, not from planning.

So 500 levels of the core rule alone will blur together after roughly 100 to 150 levels. The plan below therefore has two tracks, and the second needs approval because `plan.md` lists these mechanics as future work.

| Track | Levels | Mechanics | Approval |
|---|---|---|---|
| A: Core | 1 to 200 | Ray blocking only | None beyond this plan |
| B: Extended | 201 to 500 | Adds mechanics in the order below | Owner approval per mechanic |

Track B mechanic candidates, one per world, in this order: **locked arrows** (needs a key arrow removed first), **rotating arrows** (turn 90 degrees after each removal elsewhere), **chain reactions**. These do create real planning and wrong-move traps, which is what makes a long game worth playing. Each needs its own rules, solver and tests before any level using it ships.

If Track B is not approved, levels 201 to 500 fall back to larger, denser Track A boards plus a mistake-based rating (see section 5), with the risk of repetition noted in section 8.

## 2. Structure: 10 worlds of 50 levels

| World | Levels | Board (cols x rows) | Arrows | Min chain depth | New element |
|---|---|---|---|---|---|
| 1 | 1 to 50 | 3x3 to 5x5 | 3 to 10 | 2 to 4 | Core rule, tutorial levels 1 to 8 |
| 2 | 51 to 100 | 5x5 to 6x7 | 8 to 16 | 3 to 6 | Multiple valid first moves |
| 3 | 101 to 150 | 6x7 to 7x9 | 14 to 24 | 4 to 8 | Decoy-looking chains |
| 4 | 151 to 200 | 7x9 to 8x10 | 22 to 34 | 6 to 10 | Dense boards, near-miss rays |
| 5 | 201 to 250 | 5x6 to 8x10 | 8 to 30 | n/a | Locked arrows (Track B) |
| 6 | 251 to 300 | 6x8 to 8x10 | 12 to 34 | n/a | Locked arrows, harder |
| 7 | 301 to 350 | 5x6 to 8x10 | 8 to 30 | n/a | Rotating arrows (Track B) |
| 8 | 351 to 400 | 6x8 to 8x10 | 14 to 36 | n/a | Rotating arrows plus locks |
| 9 | 401 to 450 | 5x6 to 8x10 | 8 to 30 | n/a | Chain reactions (Track B) |
| 10 | 451 to 500 | 7x9 to 10x12 | 20 to 44 | n/a | Mixed, expert |

Maximum board for phones: 10x12, about 100 px per cell on a 1080 px wide screen. The repository's current cap of 16 per side stays as a safety limit only.

Within each world of 50:
- Levels 1 to 5 introduce the world's new element on a tiny board.
- A gentle ramp over levels 6 to 40, one difficulty dimension at a time.
- Levels 41 to 49 are a peak, then level 50 is a "boss" board: the largest or densest of the world.
- Every 10th level is slightly easier, as a breather.

## 3. Generation pipeline (seeded, offline, never at runtime)

Hand-authoring 500 boards is not realistic, and AI-drafted levels are not accepted without solver checks (`plan.md` section 8). So:

1. **Generator** (`tools/level_generator.gd`, run headless): takes a world spec (board size range, arrow count range, direction weights, target depth) and a seed.
2. **Construction by reverse placement:** choose the removal order up front, place arrows from last-removed to first-removed, and reject any placement that creates a blocking cycle. This gives solvable boards by construction, with tunable dependency depth.
3. **Validation:** every candidate goes through the existing greedy solver. For boards of 20 arrows or fewer the exhaustive cross-check also runs. For larger boards the cross-check is a separate topological-sort implementation, since exhaustive search does not scale.
4. **Metrics computed and stored per level:** arrow count, board area, longest dependency chain, number of legal first moves, number of arrows blocked at start, rays that pass within one cell of a blocker. These drive the difficulty ramp.
5. **Selection:** generate many candidates per slot (for example 200), keep the best match to that slot's target metrics, reject near-duplicates (same arrangement after rotation or mirroring).
6. **Human review:** the owner or a tester looks over each world's boards before they ship. Generated does not mean good.
7. **Output:** `data/levels/world_NN.json`, same schema as today with `version` kept at 1 plus optional `metrics` and `seed` fields. The seed and generator version are stored so any level can be regenerated and audited.

Everything is deterministic: same seed, same level. No generation happens on the player's device.

## 4. Engine and app changes needed

| Change | Why |
|---|---|
| `PuzzleRepository` loads a folder of world files | One 500-level file is hard to review |
| Level select screen with worlds, lock/unlock, best score | 500 levels need navigation; today the game just goes to "Next" |
| Level id remains the save key | Existing saves stay valid |
| Content validation command run in CI or before commit | Fails if any level is unsolvable, duplicated or off its metric band |
| Board view scales cells for up to 10x12 and respects safe-area insets | Required before large worlds |
| Track B only: rule engine, solver, tests per mechanic | Not started; each mechanic is its own milestone |

## 5. Rating without an "efficiency" metric

Because move count is fixed, proposed ratings for Track A are:
- **Clean:** cleared with zero blocked taps.
- **Fast:** cleared under a time threshold that scales with arrow count (tuned after playtests).
Both are optional and never gate progress, matching `plan.md` section 4 ("without making the basic game stressful"). Track B levels may add real move-efficiency targets once mechanics create choices.

## 6. Milestones and acceptance criteria

| Milestone | Deliverable | Done when |
|---|---|---|
| L1 | Generator + metrics + validation command | Reproduces the 4 current levels' solvability; 1000 generated boards all pass both solvers; deterministic for a fixed seed (tested) |
| L2 | Worlds folder loading + level select + scaling for 10x12 | Runs on the emulator at 1080x2424 with a 10x12 board and tappable cells |
| L3 | World 1 (50 levels) generated, reviewed, shipped | Playtest: tutorial levels completable without explanation |
| L4 | Worlds 2 to 4 (levels 51 to 200) | Metrics monotonic within each world; owner review done |
| L5 | Decision gate: approve Track B or fall back | Playtest data on whether levels 100 to 200 feel repetitive |
| L6+ | One Track B world at a time | Each mechanic has rules, tests and solver before its levels exist |

Realistic effort: L1 to L4 is the bulk of Track A. Track B is several separate features, not a content task.

## 7. Testing

- Unit tests for generator determinism, cycle rejection, and the metrics.
- A test that loads every shipped level and runs both solvers (extends today's `test_shipped_levels`).
- Property test: for random seeds, every generated board is solvable by both solvers.
- Duplicate and near-duplicate detection test across all packs.
- Manual: emulator and a physical Android device for the largest boards, touch target size, contrast.

## 8. Risks

- **Sameness (highest):** Track A has no planning, so 200 levels may already be too many. Mitigation: playtest at levels 50 and 100 before generating more, and treat 200 as the soft target if Track B is not approved.
- **Generated levels feel mechanical.** Mitigation: human review and metric-band selection; hand-craft the 10 boss boards.
- **Dense boards hard to tap or read.** Mitigation: cap at 10x12, scale test on small phones.
- **Scope creep from Track B.** Mitigation: separate milestones and separate approval.
- **Content volume vs. validation time.** Greedy solving is fast; the exhaustive check is limited to small boards.

## 9. Decisions needed from the owner

1. Approve the departure from `plan.md` (about 40 hand-curated levels to 500 generated and reviewed)?
2. Approve Track B mechanics, and in what order, or stop at about 200 levels?
3. Is Clean/Fast the right rating for Track A, or should blocked taps simply be counted?
4. Who reviews each world's levels before release?
