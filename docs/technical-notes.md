# Technical notes and follow-ups

Implementation boundaries and open technical work for Allen. The portfolio overview is in [README](../README.md).

## Security and data ownership

| Area | Current implementation | Follow-up |
| --- | --- | --- |
| Gemini credentials | Requests originate in the Flutter client. Git-ignored configuration prevents accidental source commits, but keys bundled in distributed application binaries remain extractable. | Move Gemini requests behind an authenticated backend with server-held credentials. |
| Account isolation | Profiles, personal exports, meal/weight readers and workout statistics filter ownership. Water totals are device-shared; older workout-list/mutation paths retain ownership limitations. | Complete owner checks for those paths, preserving legacy records and requiring approval for migrations. |
| Local persistence | SharedPreferences records and app-private JSON exports have no additional application-level encryption or cloud synchronization. External export sharing is not implemented. | Review encryption, backup and export requirements before wider distribution. |
| Account/data deletion | Firebase account deletion leaves local fitness records. The legacy cache-clear operation removes `weight_logs`, not current `weights` history. | Define an explicit account-data retention/deletion flow before changing destructive behavior. |

Source: [AI service](../lib/fitness/services/ai_service.dart), [local storage](../lib/fitness/services/local_storage_service.dart), [workout repository](../lib/fitness/repositories/workout_repository.dart), [profile repository](../lib/features/auth/data/user_repository.dart), [export service](../lib/fitness/services/profile_export_service.dart), [Firebase authentication repository](../lib/features/auth/data/firebase_auth_repo.dart), and [legacy storage](../lib/fitness/services/storage_service.dart).

## Open remediation checklist

- [ ] Introduce backend-mediated Gemini requests and server-side credential management.
- [ ] Scope water data to accounts and enforce ownership throughout workout reads and mutations; add account-switch regression coverage.
- [ ] Define local data/export retention and explicit cleanup behavior for account deletion.
- [ ] Assess storage/export encryption and backup requirements.

These items are tracked follow-ups, not implemented capabilities. Existing unowned legacy profiles/weights remain preserved and excluded from personal summaries; personal exports omit foreign and unowned records. No automatic ownership reassignment is performed by those readers.

## Feature boundaries

- Gemini guidance and photo nutrition values are estimates that users review before saving.
- AI Coach conversations are temporary; persistent chat history is not implemented.
- Notifications support Android permission/status checks and an explicit test notification. Daily reminders are not scheduled.
- Theme, measurement units and language are fixed to the current supported settings.
- Live-service, process-restart, device and accessibility regression checks complement automated tests.
