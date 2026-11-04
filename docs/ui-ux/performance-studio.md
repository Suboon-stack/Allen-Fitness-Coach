> Historical design record. The selected current palette and reviewed-screen styling are specified in [Midnight Navy + Electric Blue](midnight-theme.md).

# Performance Studio — approved direction

The owner selected Option A: ink navy, electric cobalt, warm white, and restrained lime accents. The current review scope is authentication only. The previously implemented green Home remains unchanged pending its own approval.

## Design rationale

Allen combines workouts, nutrition, and conversational guidance. Performance Studio uses an editorial layout and a continuous track motif to suggest momentum without suggesting invented activity or progress. The welcome screen has a dark brand composition followed by a practical explanation and two entry paths. The graphic is drawn in Flutter; it is not a user metric, chart, or generated photograph.

The visual change is structural: the centered lock/form composition becomes a welcoming introduction and a focused form flow. On wide screens, an ink narrative panel sits beside a constrained form. On phones, the narrative panel is omitted from forms to prioritize the task. Reset has a dedicated route with input, pending, failure, and completion states rather than a transient dialog.

## Design tokens

| Role | Light | Dark |
| --- | --- | --- |
| Brand ink | `#11172B` | `#11172B` |
| Action | Cobalt `#3154EC` | Periwinkle `#B9C4FF` |
| Supporting brand accent | Lime `#D6F47A` | Lime `#D6F47A` |
| Canvas | Warm white `#F5F5F1` | Ink `#11172B` |
| Input surface | White | `#1C2339` |
| Primary text | Ink | `#F2F3FA` |
| Secondary text | `#596174` | `#B9C0D3` |
| Input outline | `#7C8496` | `#8590AB` |

Material ColorScheme supplies error, disabled, focus, and inverse-surface roles. Lime is decoration on ink, not body text on white. Typography uses system Material fonts without downloading another family: display 42/1.06, heading 30/1.15, title 22/1.25, body 16/1.5 and 14/1.5, action 15–16 bold. Informational text respects system scaling. The wordmark is a fixed-size brand lockup with a readable text semantic label.

Spacing uses 8/16/24/32px increments. Inputs and buttons use 16px corners; the welcome/desktop brand panel uses 28–32px corners. Forms are constrained to 440px; the overall composition is constrained to 1160px. At 900px, auth changes from a single-column form to the split composition. It scrolls rather than hiding fields at larger text sizes or when the keyboard appears.

## Components

- PerformanceScope / PerformanceTheme: light and dark Material 3 themes scoped to approved screens. No theme preference or storage key is introduced.
- StudioWordmark / MovementArtwork: brand identity; artwork is excluded from assistive semantics.
- StudioAuthLayout: safe-area, keyboard-resizing, scrollable layout; stable 48px header and a desktop narrative panel.
- StudioField: permanent floating label, input hint, in-place validation, autofill, next/done keyboard actions, and a 48px password visibility control.
- StudioButton: full-width primary action, minimum 56px height, disabled pending state, progress and live status text.
- StudioNotice: actionable inline error in semantic error colors, announced as a live region.

No gradients, remote images, fabricated statistics, new packages, or ornamental animations were added. This is source-informed design work under the owner's brief. It is not evidence of user research, usability testing, or accessibility certification.
