# Profile & Settings — repair record

These functionality changes are documented separately from visual decisions.

## Profile ownership

**Root cause:** the original repository stored one global `user_profile` and decoded it without verifying its stored `id`. Editing could reuse a previously loaded profile ID. Nutrition/Progress target readers also used that global source.

**Fix:** add UID-specific keys; require live authenticated ownership in UserRepository reads/writes; reject mismatched owned-key contents; read a global legacy profile only when its existing `id` matches. Serialize writes, verify native acknowledgment and recheck ownership around asynchronous work. New UI uses the captured authenticated UID, not a profile object's previous owner. Target readers pass the current UID to the shared lookup. Preserve the legacy key without automatic claiming/deletion/migration.

## Workout statistics

**Root cause:** count/streak methods accepted a user ID but called shared local aggregations that ignored it. The profile and dashboard could count other accounts' workouts.

**Fix:** use the existing exact-owner completed-workout projection for profile data and shared count/streak methods. Deduplicate calendar dates for streaks; do not count future records in streaks. Preserve original workout records and repository method contracts. Broader workout ownership repair remains separate.

## Registration names

**Root cause:** registration collected `name`, but the Firebase repository discarded it.

**Fix:** trim and submit the name through the newly created Firebase User's supported display-name update. Skip stale credential identities; after awaiting metadata, return the actual current Firebase identity. Name-update failure does not undo successful account creation or fabricate a registration failure. Optional AppUser displayName remains backward-compatible with older JSON. Local profile editing is explicitly account-scoped.

## Notifications

**Root cause:** a persisted reminder flag and immediate `show` calls were presented as daily scheduling. No recurring scheduler or permission/status flow existed.

**Fix:** replace the misleading toggle with Android permission/status and explicit test delivery. The retained scheduling API now rejects unsupported scheduling instead of firing an immediate fake reminder. Never enable a daily schedule. Existing old preferences are not migrated or treated as evidence of scheduling. Android remains the source of permission state; settings reread it on reopen/resume.

## Export and serialization

**Root cause:** raw workout/meal/weight lists were exported without account filtering. Profile export used the Firestore serializer, whose Timestamp values cannot be JSON-encoded directly. A single fixed filename could overwrite another account's export.

**Fix:** export exact-owner local JSON records with ISO profile dates, explicit exclusions and unique filenames in the existing app-private Documents directory. Reject stale sessions and keep raw exceptions out of UI. No changes to the stored workout/meal/weight lists. External export sharing requires a separately scoped implementation; it is not simulated with clipboard content or a fake download.

## Existing destructive operations

Firebase account deletion and StorageService.clearWeightLogs are unchanged. Their confirmations now describe actual effects: Firebase sign-in deletion leaves local records, and the old `weight_logs` clear operation does not purge current Progress `weights`. No new bulk clear or account-data deletion/migration has been introduced.

See the [case study](profile-settings-redesign.md) for tests and remaining device checks.
