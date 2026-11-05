class_name LeaderboardSync
extends RefCounted
## Which star total still has to reach the online leaderboard. Pure logic: the
## Play Games service asks what to send and reports what was confirmed. Scores
## come only from the local save, so a failed or offline submit is simply
## retried later (on launch, sign-in or the next return to the menu).


## The star total to submit for `tier`, or -1 when the leaderboard already has
## it (or there is nothing to send yet).
static func score_to_submit(progress: Progress, tier: int) -> int:
	var stars := progress.total_stars(tier)
	if stars <= 0 or stars <= int(progress.leaderboard_sent.get(tier, 0)):
		return -1
	return stars


## Records that the leaderboard accepted `score` for `tier`. Never lowers it.
static func mark_submitted(progress: Progress, tier: int, score: int) -> void:
	if score > int(progress.leaderboard_sent.get(tier, 0)):
		progress.leaderboard_sent[tier] = score
