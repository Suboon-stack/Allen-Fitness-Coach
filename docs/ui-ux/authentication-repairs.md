# Authentication repairs — Performance Studio

These targeted repairs are separate from the visual redesign. No AuthRepo signature, Firebase configuration, local key, record format, or fitness repository is changed.

## Root causes and implementation

- Form loss: IntroGate replaced AuthPage with a loading Scaffold, disposing its controllers. Gate now keeps the form subtree mounted through requests; AuthPage keeps both forms mounted through switching.
- Session restoration: checkAuth had an uncaught await; intro was presented before the result. Restoration now waits for the repository, skips intro for a valid session, and exposes a retry state if verification fails.
- Logout: cached identity was never cleared and errors were uncaught. Both logout and deletion now reconcile via AuthRepo.getCurrentUser; cache and emitted state reflect that result.
- Deletion failure: catch always emitted Unauthenticated even for requires-recent-login. It now restores the actual session, explains reauthentication, and reports verification failure explicitly if the session cannot be read.
- Stale account routes: replacing the gate alone left pushed account pages visible after logout. Confirmed sign out returns navigation to the root.
- Error handling: FirebaseAuthRepo wrapped exceptions as generic strings, hiding error codes. Firebase exceptions now retain their codes for safe, actionable messages. Existing reset success string is preserved.
- Duplicate authentication submissions: loading state guards repeated actions.

Registration name persistence, external session-change subscriptions, fitness account ownership, and data cleanup are not implemented here. Local data is retained on logout/deletion. No migration was performed.

## Evidence

`test/auth/auth_cubit_test.dart` exercises restoration/retry, logout/deletion success and failure, recent-login rejection, uncertain-session recovery, duplicate submission, credential trimming, and reset error mapping through an in-memory AuthRepo test double. These tests do not claim live Firebase verification. Widget coverage is recorded with the visual stage.
