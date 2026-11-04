# Implementation and review notes

## Scope and Git safety

Work is on `redesign/performance-studio-auth`. Pre-existing uncommitted Home/theme/main/test work and the initial documentation/components were preserved. A copy of those files was saved under `/tmp/allen-before-performance-auth` before implementation. Nothing was pushed or merged.

Authentication repairs were committed separately from presentation work. The original AuthRepo contract, Cubit approach, Firebase project/options/keys, Gemini calls, fitness repositories, SharedPreferences keys, and user records are unchanged. Name persistence remains a follow-up; no schema migration is introduced here.

Performance Studio lives in authentication presentation files rather than changing the green Home theme or legacy fitness palette. This deliberate staging boundary means the transition into Home still shows the previous design until that stage is reviewed.

## Deferred functionality work

| Issue | Root cause / evidence | Status |
| --- | --- | --- |
| Workout completion | Exercise name passed where saved UUID is expected | Deferred |
| Dashboard statistics / weight clearing | Legacy StorageService keys differ from repository keys | Deferred |
| Weight deletion | Newly logged weight records do not carry the IDs deletion expects | Deferred; discuss backward-compatible migration before changing records |
| Account data separation | Local records/profile keys are shared; reads do not isolate ownership | Deferred; requires an explicit data-ownership/migration decision |
| Reminders | Enabling shows a notification, not a recurring schedule | Deferred |
| AI fallbacks | Service silently substitutes predefined plans on errors | Deferred |
| Registration name | Existing name argument is not persisted | Deferred; documented limitation |

## Validation

Use `/home/suboon/flutter/bin/flutter` and its Dart executable. The system `/usr/bin/flutter` fails with a snapshot mismatch; the alternate installed SDK builds and tests this project without modifying the system installation.

Final command outcomes and device observations are recorded below after execution. Unit/widget tests use fake AuthRepo instances only inside tests; production continues using FirebaseAuthRepo. Tests do not send reset emails, create/delete real accounts, or change stored fitness records.

Existing Home's drawer test used `.last` on a lazy finder before a tile was built, which threw rather than allowing scrolling. The test locator is now scoped to Drawer without `.last`. No Home implementation change was made in this stage.

### Executed checks

- Dart formatting: completed using the working SDK.
- `flutter test`: **29 passed** (12 Cubit tests, 12 authentication widget tests, 5 existing Home tests).
- `flutter analyze lib/features/auth lib/intro test/auth`: **passed**, no issues.
- Full `flutter analyze`: **14 diagnostics** in untouched fitness pages/repository (5 warnings, 9 infos); nonzero exit. No authentication diagnostics remain.
- Android debug APK build: **passed**.
- `git diff --check`: passed.

Device preview uses a separate temporary AVD named Allen Performance Preview at `/tmp/allen-auth-preview-avd`, with a fresh app-data directory and the same Android 36.1 system image. The original emulator's account data was not cleared or signed out. Welcome and registration validation were inspected as actual Android renders. An Android status-bar contrast issue found during inspection was corrected using system overlay styles scoped to authentication.

Remaining manual checks: live Firebase sign-in/registration, actual reset-email delivery, valid-session restoration across a process restart, failed/successful sign-out and account deletion against Firebase, password manager autofill, TalkBack, and physical-device keyboards. Automated tests verify session logic through a fake repository; they do not substitute for those integration checks. No real account was created/deleted and no reset email was sent during the automated tests or screenshot navigation.
