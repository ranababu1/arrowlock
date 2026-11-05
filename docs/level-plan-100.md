# Release 1 Plan: 100 Levels, Move Limits, Rewards, Leaderboard

**Status:** Approved and implemented through R4, plus the online leaderboard code (R8); owner decisions of 2026-11-05 are in section 11. Supersedes the scope of `level-plan-500.md` for the first release (that document is deferred, not deleted). `plan.md` is unchanged. Where this plan and the decisions in section 11 differ, section 11 wins.

## 1. Owner decisions captured from chat (2026-11-01)

1. First release ships **100 levels**.
2. If a unique layout cannot be found, a layout may be **reused under a different level name**.
3. **Every tap on an arrow is a move.** Tapping an arrow that is not clear wastes a move.
4. Each level has a **limited number of moves**. Running out with arrows left is **game over**.
5. Plan **rewards and a leaderboard**, because the game targets Android.

Departures from `plan.md` (recorded here and in the changelog; `plan.md` itself stays as the baseline):
- `plan.md` section 2 says blocked taps should not punish experimentation in the MVP. Decisions 3 and 4 reverse that.
- `plan.md` excludes online leaderboards, accounts and a backend from the MVP. The leaderboard is therefore split into a local part (release 1) and an online part that needs separate approval (section 7).

## 2. New rules

| Rule | Definition |
|---|---|
| Move | One tap that lands on an arrow, clear or blocked |
| Wasted tap | A move spent on a blocked arrow; state unchanged except the counter |
| Move limit | `moves_limit` per level, stored in the level file |
| Win | All arrows removed with `moves_used <= moves_limit` |
| Game over | `moves_used == moves_limit` and arrows remain |
| Solvability invariant | `moves_limit >= arrow_count` (a perfect player needs exactly `arrow_count`), enforced by validation and tests |

Why this restores difficulty: a perfect reader never fails, but a misread ray now costs a move. Difficulty comes from how tempting a blocked arrow looks and how little slack the level allows.

**Open questions with a recommendation:**
- **Tap on an empty cell:** free. Penalising missed touches would punish fat fingers, not misreading.
- **Undo:** restores the last removed arrow and refunds that one move, but does not refund wasted taps. Costs a coin (section 5) so it is a resource, not a free reset.
- **Restart after game over:** free and instant. No lives or energy system in release 1.
- **Pause/background:** the move count is state, saved with the session so an interrupted level resumes.

## 3. Difficulty and move-limit curve

10 worlds of 10 levels. Slack means `moves_limit = ceil(arrow_count * (1 + slack))`, and always at least `arrow_count + 2`.

| World | Levels | Board (cols x rows) | Arrows | Slack | Focus |
|---|---|---|---|---|---|
| 1 | 1 to 10 | 3x3 to 4x4 | 3 to 6 | 100% | Tutorial: one rule per level, blocked tap taught on level 3 |
| 2 | 11 to 20 | 4x4 to 5x5 | 5 to 9 | 75% | Chains of 2 to 3 |
| 3 | 21 to 30 | 5x5 to 5x6 | 8 to 12 | 60% | Several free arrows at once |
| 4 | 31 to 40 | 5x6 to 6x7 | 10 to 15 | 50% | Long rays that end in a late blocker |
| 5 | 41 to 50 | 6x7 | 12 to 18 | 40% | First tight levels |
| 6 | 51 to 60 | 6x8 | 14 to 21 | 35% | Dense lanes, bait arrows |
| 7 | 61 to 70 | 7x8 | 16 to 24 | 30% | Deep chains |
| 8 | 71 to 80 | 7x9 | 18 to 27 | 25% | Dense and tight |
| 9 | 81 to 90 | 8x9 | 20 to 30 | 20% | Expert |
| 10 | 91 to 100 | 8x10 | 22 to 34 | 15% | Expert; level 100 is the largest board |

Largest board is 8x10, about 130 px per cell on a 1080 px wide phone. Every 5th level is a slightly easier breather; the 10th is the world's hardest.

**Stars (per level):** 3 stars = zero wasted taps, 2 stars = wasted taps use at most half the slack, 1 star = cleared. Best result per level is kept.

## 4. Level production

- **Generator:** seeded, offline tool (`tools/`), builds solvable boards by reverse placement (choose a removal order, place arrows last-removed first, reject cycles). Seed and generator version stored in each level. Nothing generates on the player's device.
- **Validation:** greedy solver plus an independent cross-check (exhaustive up to about 20 arrows, topological sort above). Plus `moves_limit >= arrow_count`.
- **Difficulty metrics per level:** arrow count, longest dependency chain, arrows blocked at start, count of "bait" arrows (a long clear run before a late blocker), slack. Chosen per slot to hit the table above.
- **Review:** the owner plays each world and flags levels; 100 levels is small enough to review all of them.
- **Reuse policy (decision 2):**
  - A reused layout is a rotation, mirror or transpose of an existing board, or the same board with a new slack, and gets a new name and its own id.
  - Canonical-form dedupe tooling reports every reuse so none is accidental.
  - Limits: at most 15 of 100 levels reused, never within 10 levels of the original, never in World 1 (tutorials must be distinct).
  - Reuse is recorded as `"variant_of": <level id>` in the level file.

## 5. Rewards

Release 1 has no ads, no purchases and no accounts (`plan.md` section 4), so every reward is earned by playing.

| Reward | How it is earned | Use |
|---|---|---|
| Stars | 1 to 3 per level, best kept | Progress, shown on level select, drives the leaderboard score |
| Coins | 10 on first clear, +5 per star first earned, +5 per star improved on replay, +25 world-complete bonus; 100 starting coins | Spent on helpers |
| Helper: Undo | 20 coins | Restore the last removed arrow and refund that move |
| Helper: Hint | 30 coins | Highlight one currently clear arrow |
| Helper: Extra moves | 50 coins | After game over, continue the same board with +3 moves (once per attempt) |
| World unlock | Clear 8 of 10 levels in the previous world | Prevents one hard level from blocking the game |
| Milestone badges | First clear, 10/50/100 levels, first world at 3 stars, a level cleared with zero wasted taps | Local badges now; map to Play Games achievements later |

Balance goal to verify in playtesting: a player who clears levels normally can afford about one helper per world without grinding. Prices and payouts are tuning constants kept in one config file, not scattered in code. Coin and star totals are validated on load so a corrupt save cannot produce negative balances.

## 6. Save schema v2

Fields: per-level `stars`, `best_moves_used`, `best_wasted`, plus `coins`, helper inventory, unlocked world, badges, settings, and optionally an in-progress session snapshot. A v1 save (`completed` map) migrates to 1 star per completed level. Corrupt data still falls back to defaults. Migration and corruption cases get tests.

## 7. Leaderboard

**Release 1 (local, no approval needed beyond this plan):** a personal-bests screen: total stars out of 300, levels cleared, fewest wasted taps per level, badges. No network.

**Online leaderboard (separate approval):**

| Item | Proposal |
|---|---|
| Service | Google Play Games Services leaderboards, no custom backend |
| Board | One all-time board: total stars (maximum 300). Optional second board later |
| Sign-in | Play Games sign-in only, optional; the game stays fully playable offline and signed out |
| Dependency | A Godot Play Games plugin (third-party), reviewed for maintenance, licence, permissions and size before adoption, per `instructions.md` section 4 |
| Console work | Play Console game services project, leaderboard and achievements definitions, OAuth credentials kept out of Git |
| Compliance | Privacy policy and Data safety answers updated for the player id and score |
| Cheating | Scores are client-submitted and cannot be verified without a backend. Accept this for a casual game; scores are posted only after the local save records the stars |
| Failure handling | Submission failures never block play; scores queue and retry on next launch |

This conflicts with the `plan.md` exclusions, so it is held for explicit owner approval and does not block the first release candidate.

## 8. Engine and UI changes

| Area | Change |
|---|---|
| `GameController` | Add `moves_limit`, `moves_used`, `wasted_taps`, state (playing, won, lost); `lost` signal; blocked tap costs a move; win and loss each fire exactly once |
| Level schema v2 | `moves_limit`, optional `variant_of`, `metrics`, `seed`; v1 files still load |
| `PuzzleRepository` | Load world files, validate `moves_limit >= arrow_count` |
| UI | Moves-left display, game-over panel (Retry, Use extra moves), win panel (stars, coins earned), level select with worlds and stars, helper buttons with prices, personal-bests screen |
| Board view | Scale to 8x10, respect safe-area insets (currently fixed 16 px margins), centre the board |
| Accessibility | Moves-left and stars readable without colour; blocked feedback not colour-only (add a shake or marker) |

## 9. Milestones

| ID | Deliverable | Done when |
|---|---|---|
| R1 | Move-limit rules in the engine with tests | Tests cover: blocked tap costs a move, empty tap free, loss fires once, win on the last allowed move, undo refund, limit below arrow count rejected |
| R2 | Save v2 + migration + reward economy as pure logic | Tests for payouts, star calculation, v1 migration, corrupt save, no negative coins |
| R3 | Generator + validation + reuse tooling | 1000 generated boards pass both solvers; deterministic per seed; reuse report works |
| R4 | UI: HUD, game over, rewards, level select, scaling | Verified on the emulator at 1080x2424, including an 8x10 board |
| R5 | World 1 to 3 (levels 1 to 30) playable | Owner playthrough; tutorial usable without explanation |
| R6 | All 100 levels | All validated; owner reviewed; reuse count within policy; playtest notes on difficulty spikes |
| R7 | Android release candidate | Internal test track, physical device test, pause/resume, upgrade-from-previous-build test, Play listing checklist per `instructions.md` section 7 |
| R8 | Online leaderboard (only if approved) | Works signed in and out; failures do not affect play |

## 10. Risks

- **Frustration from game over.** Mitigation: generous early slack, free instant retry, hint and extra-move helpers, 8-of-10 world unlock.
- **Tuning is guesswork until played.** Slack, prices and payouts are config values; plan a tuning pass after R6.
- **Bait arrows need visual care.** Dense boards must stay readable; test on a small phone.
- **Coins create an economy to maintain.** Kept deliberately small, earn-only, no purchases in release 1.
- **Online leaderboard adds a dependency, console setup and privacy work.** Held back from release 1 by design.

## 11. Decisions (owner, 2026-11-05)

1. **Taps on empty cells stay free.** Confirmed.
2. **Undo takes back exactly one tap**, a wasted tap or a removal, and refunds that move; a wasted tap that is undone no longer counts as wasted. Still costs coins. (Replaces "refunds only the removed arrow's move".)
3. **Reuse: none.** The owner left this to the agent. Decision: every shipped level is a unique layout; the generator no longer falls back to rotated copies (`allow_variants: false`) and the tests fail if a pack contains one. The validator keeps the old limits (15 of 100, not in World 1, 10 apart) only as a safety net for future packs.
4. **Play Games leaderboard approved; build it now.** Two boards (Easy stars, Difficult stars). Code is in; the Play Console setup is an owner step (`docs/release.md`).
5. **Stars (3 = no wasted taps) and the 8-of-10 world unlock:** confirmed.

Further owner direction the same day:
- **No owner level review for now.** Both packs must get harder level by level instead of in steps with breathers: the arrow count never drops, the dependency chain never gets shallower, spare moves per arrow never grow, and level 100 is the hardest. Enforced by tests. Replaces the "every 5th level is a breather" rule in section 3.
- **Losing only at 0 moves** stays, even when the board is already unwinnable, so players spend more time on a level.
- **The per-tap clock is Difficult-only** (10 s). Easy has no clock at all (it had 20 s from level 31).
- Coin balance and the level freeze were left to the agent: see the changelog of 2026-11-05.
- Audio and tutorial review: later; nothing waits for it.
