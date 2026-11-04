# Dashboard-specific repairs

These changes are confined to Home. Repository contracts, local record formats, authentication, and Gemini requests are unchanged.

## Incorrect statistics source

Home read `StorageService` (`workout_count`, `streak`, `weight_logs`), whereas workout/progress screens use repositories backed by `LocalStorageService` (`workouts`, `weights`, and daily water keys). The root cause was explained before implementation. Home now reads WorkoutRepository.getWorkoutCount/getCurrentStreak and ProgressRepository.getLatestWeight/getTodayWaterIntake for the current authenticated user.

Regression coverage seeds conflicting legacy and repository values, then verifies that Home displays the repository-backed completed count, latest weight, streak, and water. No records are migrated, rewritten, or deleted. Legacy records in the old keys are retained but are not used by Home. Account-level isolation remains an existing repository limitation and is not repaired by this change; the UI does not claim these device-wide records are isolated per account.

## Activity blocked by Gemini

Home previously awaited the daily quote before reading local statistics. A slow network request delayed the entire dashboard. Quote loading is now independent of activity loading. Pull-to-refresh waits only for local activity; the quote has its own loading/retry state inside a collapsed disclosure. A pending-quote regression test confirms statistics still render.

Workout completion, weight IDs/deletion, account ownership, reminder scheduling, and AI fallback behavior remain deferred.
