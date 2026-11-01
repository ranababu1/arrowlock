# Development Instructions

## 1. Purpose and authority

This file defines the mandatory engineering workflow for this project. Follow it for every implementation task, whether the work is performed by a human developer or an AI coding agent.

- `plan.md` is the original product and engineering plan. Treat it as an immutable baseline. Do not silently rewrite, restructure, or replace it as the project evolves.
- If implementation requires a material departure from `plan.md`, document the rationale, alternatives, risks, and approval in `changelog.md` and `currentstate.md`. Change `plan.md` only when the project owner explicitly requests a revision. Preserve the original plan history if an approved revision is made.
- `changelog.md` and `currentstate.md` are required living documents. Create and maintain them from the beginning of development.
- Do not state or imply that a feature is implemented, tested, released, or measured until evidence supports that claim.

## 2. AI-agent operating protocol

Before editing:
1. Read `instructions.md`, `currentstate.md`, the relevant sections of `plan.md`, and the latest `changelog.md` entries.
2. Inspect the current branch, working tree, project structure, toolchain version, and available tests.
3. Identify user changes and preserve them. Never overwrite unrelated edits.
4. State the smallest coherent implementation plan, the files expected to change, and the validation commands.
5. Search for an existing implementation before creating a new one. Prefer a focused change over a broad refactor.

While editing:
- Implement only the requested scope. Do not introduce accounts, remote services, analytics SDKs, ads SDKs, dependency frameworks, or architectural layers without a documented need and approval.
- Follow the established architecture and naming conventions. Explain any new dependency or architectural decision in the changelog.
- Keep gameplay rules deterministic and separable from rendering, input, audio, and platform APIs.
- Use seeded random number generation whenever reproducibility is important for puzzle generation, challenge generation, or tests.
- Handle errors explicitly. Do not swallow exceptions or add empty catch blocks.
- Never fabricate test output, build results, performance numbers, store status, or feature completion.
- Do not add TODOs as a substitute for implementation. If work is intentionally deferred, record it in `currentstate.md`.

Before committing:
1. Run formatting, static analysis/lint, compilation/export checks, and relevant automated tests available for the changed scope.
2. Review `git diff` and `git diff --cached`; inspect every changed file for accidental edits, debug code, credentials, generated files, and unrelated changes.
3. Update `changelog.md` with meaningful implementation details, fixes, test evidence, and any user-visible changes.
4. Update `currentstate.md` with what is actually implemented, current architecture, known issues, test/build status, outstanding work, and next steps.
5. Ensure the working tree contains no unrelated changes staged by the agent.
6. Commit using a focused, descriptive message. Do not add AI co-author trailers.
7. Push according to the Git rules below and verify the push succeeded.

## 3. Buildability and Git workflow (mandatory)

- Work on the intended existing branch unless the project owner explicitly authorizes a branch change. Do not create or switch branches without checking the repository's existing workflow and obtaining authorization where required.
- Preserve all pre-existing user changes. Do not discard, reset, stash, or overwrite them without explicit permission.
- Keep the project buildable at all times. Prefer small, coherent, compilable increments.
- Frequently committing changes.
- **Push after every file change when a new file is written or approximately 50 lines of code have changed since the previous push, whichever comes first.** If any requirement dsnt require 50 lines of code, dnt block the code push.
- After each push, verify success using the Git command output and, where available, the remote branch status. Report the commit hash and verification result accurately.
- Review diffs before committing. Use focused, descriptive commit messages such as `feat: add seeded puzzle generator` or `fix: prevent duplicate score submission`.
- Do not use AI co-author trailers in commit messages.
- Never run destructive operations such as `git reset --hard`, `git clean -fd`, force-push, history rewriting, or branch deletion without explicit authorization.
- Do not amend or rewrite shared commits unless explicitly authorized.
- Push only to the configured remote and intended branch. If no remote is configured, credentials are unavailable, or the push is rejected, do not invent success; explain the blocker and the exact next step.

## 4. Repository hygiene and security

- Never commit secrets, API keys, access tokens, signing keys, passwords, private certificates, production credentials, personal data, or databases containing user data.
- Never commit build outputs, exported APKs/AABs, caches, editor state, temporary files, crash dumps, or generated artifacts that should be excluded. Store release binaries in the release process or approved artifact storage, not as ordinary source files.
- Ensure `.gitignore` covers the selected Godot or Flutter toolchain, IDE/editor files, OS files, caches, build/export output, local secrets, and local test artifacts.
- Use environment variables or local, ignored configuration for any future credentials. No secrets should be embedded in the client app.
- Request only permissions required for an explicitly approved feature. Explain why each permission is necessary.
- Minimize collection and retention of user data. Do not introduce a backend merely to store data that can safely remain on-device.
- Review dependencies for maintenance status, licensing, permissions, size, platform compatibility, and security before adoption. Pin or constrain versions appropriately and document them.
- Do not collect advertising IDs, contact lists, location, or other sensitive data unless the owner approves a clearly justified use case and the store disclosures are updated.

## 5. Coding standards and architecture

- Keep gameplay/domain logic independent from scene nodes, widgets, platform APIs, networking, analytics, and presentation code where practical.
- Use descriptive names, small cohesive functions, explicit types where supported, and constants for tuning values. Avoid unexplained magic numbers.
- Separate content/configuration from logic when this improves balancing or testing; avoid overengineering a data-driven framework before there is a concrete need.
- Prefer deterministic, reproducible logic for scoring, challenge generation, puzzle validation, and save migrations.
- Handle pause/resume, app backgrounding, screen rotation where relevant, low-memory recovery, and interrupted sessions deliberately.
- Make touch targets comfortable for phones, respect system insets, support common aspect ratios, and ensure essential text remains legible.
- Do not block the main thread with expensive work. Profile before adding concurrency or optimization complexity.
- Add comments for non-obvious constraints and algorithms, not comments that merely restate the code.
- No hard-coded user-facing strings if localization is planned for the current milestone. Keep initial localization scope explicit.

## 6. Testing requirements

Every meaningful change must have tests proportionate to risk. At minimum, add or maintain automated tests for:
- Core gameplay rules and state transitions.
- Scoring, combo, move/attempt limits, failure and success conditions.
- Puzzle validity, solvability, and generator edge cases where applicable.
- Progression and difficulty/configuration boundaries.
- Save-state persistence, loading, invalid/corrupt data handling, and schema migration where applicable.
- Daily challenge determinism and date/time boundary behavior where applicable.
- Reproducible bug regressions.

Also perform practical device/manual checks for touch input, pause/resume, audio settings, screen sizes, accessibility/contrast, and performance. Test on a physical Android device before a production release. Record actual commands, outcomes, and limitations. A skipped test must be labeled skipped with a reason, not passed.

## 7. Versioning and release management

- Keep application version name and version code/build number in one authoritative place per toolchain; avoid conflicting duplicate values.
- Use semantic versioning for product-facing versions where suitable: `MAJOR.MINOR.PATCH`. Increment Android version code monotonically for every uploaded release.
- Keep debug, internal testing, closed testing, and production configuration distinct.
- Never publish directly to production without explicit release approval.
- Before release, verify package/application ID, app name, icon, orientation, target SDK and current Google Play requirements, privacy policy and Data safety answers, content rating, ads declaration, permissions, signing, crash-free startup, save migration, and release notes.
- Keep signing credentials outside Git and use a secure local or CI secret store. Never send signing secrets to an AI agent.
- Build and test a release candidate, install it on a clean device/profile, verify upgrade behavior from the previous version, and retain reproducible build instructions.
- Document the exact artifact filename, version name, version code, commit hash, test evidence, and release approval. Never claim a Play listing or release exists before it does.

## 8. Documentation maintenance

### `changelog.md`
Record meaningful changes in reverse chronological order. Each entry should include:
- Date and version/commit when known.
- Summary of changes and implementation details.
- User-visible impact and relevant fixes.
- Tests/build/export commands actually run and their outcomes.
- Known regressions, migration notes, dependency changes, and release notes where relevant.

Do not log every trivial keystroke. Do log changes that alter behavior, architecture, dependencies, release readiness, or known issues.

### `currentstate.md`
Keep this concise, accurate, and useful as a handoff document. It must include:
- Project purpose and current phase.
- Actual implementation status by feature (implemented, partial, planned, blocked).
- Architecture and important files/modules.
- Toolchain and dependency versions if verified.
- Current build/test/export status, including the last verified date and exact commands.
- Known issues, risks, and unimplemented items.
- Next recommended actions in priority order.
- Current version/branch/commit when known.
- Decisions or deviations requiring owner approval.

Update both files in the same implementation increment as the code change whenever feasible, before committing. Do not mark a feature implemented merely because it is described in `plan.md`.

## 9. Definition of done

A task is done only when:
- Scope and acceptance criteria are met.
- Code is buildable and relevant tests pass, or any blocked/skipped validation is clearly explained.
- `changelog.md` and `currentstate.md` accurately reflect the change.
- `plan.md` remains unchanged unless the owner explicitly approved a revision.
- Diff and staged diff have been reviewed.
- No secrets or excluded artifacts are included.
- A focused commit has been created and the configured push has been verified, or the exact reason pushing could not be completed is reported.
