# Authentication — screen decisions

| Screen | Previous problem | Implemented composition / interaction |
| --- | --- | --- |
| Welcome | Centered dumbbell avatar, spaced brand text, feature-list card | Ink typographic hero with a custom track graphic, plain-language introduction, feature pillars, registration primary action and a direct sign-in path |
| Sign in | Large lock, no page title, non-scrolling Column, unlabeled hints, snackbar validation | Clear heading and supporting text, constrained form, visible labels, inline errors, password visibility, reset entry and account switch |
| Registration | Long spaced uppercase text and overflow-prone footer | Concise hierarchy, grouped form, field-specific name/email/password/confirmation validation, wrapping account switch |
| Reset | Dialog reuses login email controller; success clears login value and uses dialog context after pop | Independent route/controller prefilled with login email; pending/error/completion content; safe dismissal during a request; return preserves sign-in draft |
| Session check | Intro before session lookup, spinner on every authentication request | Initial verification first; restored user enters existing Home; retry on failed verification; pending login stays in place |

## Interaction details

Welcome “Get started” opens registration; “Sign in” opens login. Both auth forms remain mounted so switching preserves each draft. Back returns to welcome; while submitting, form interaction and duplicate submission are disabled. Validation does not trim passwords; names and emails are trimmed before the unchanged repository calls. Login accepts an existing password of any nonempty length, while new-password guidance uses Firebase's minimum of six characters.

Errors are concise and do not expose raw backend exceptions. Password-reset success uses conditional wording (“If an account uses…”) rather than promising an account exists. The state reflects the actual result of the existing reset API; a failed request does not show a success screen.

Successful session restoration skips welcome. Account operations reconcile against the repository's actual Firebase session; failed deletion that requires a recent login retains access and explains the next step. Verified sign-out removes pushed account pages. Fitness data is not cleared or migrated.

## Current limitations

Firebase display-name persistence is unchanged: the existing registration name argument is still passed, but the repository does not yet save it. External session-change subscriptions are not added in this stage. Live Firebase delivery, autofill providers, TalkBack, and real account deletion need manual integration checks. Unrelated fitness bugs are tracked separately.
