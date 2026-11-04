# Before / after screenshot checklist

Use the same Android emulator, dimensions, system brightness, font scale, and keyboard state for each pair. Record build/commit and device in captions. Review captures for personal information before sharing. Never include passwords, tokens, or real account details.

A checklist entry is not evidence of a captured screenshot or usability study. Any screenshots included in `screenshots/` must be actual renders; do not substitute design mockups for implemented screens.

| Capture | Before | After | Comparison focus |
| --- | --- | --- | --- |
| Welcome, light mode | Pending | Captured: `screenshots/welcome-light.png` | Composition, hierarchy, CTA reachability |
| Sign in, empty | Pending | Pending | Labels, action prominence, spacing |
| Registration, empty | Pending | Pending | Field grouping and account switching |
| Password reset, empty | Pending | Pending | Old dialog vs dedicated route |
| Empty registration validation | Pending | Captured: `screenshots/registration-validation-light.png` | Actionable field errors |
| Login with keyboard | Pending | Pending | Scroll/access to primary action |
| Dark mode | Pending | Pending | Contrast and coherent surfaces |
| 200% system text, 320px width | Pending | Widget-tested, capture pending | Reflow and touch targets |
| Wide split composition | Not previously present | Widget-tested, capture pending | Brand/form balance |
| Request pending / error | Pending | Widget-tested, capture pending | Draft retention and recovery |
| Reset completion | Pending | Widget-tested, live delivery pending | Confirmation and return action |

Record image filenames and capture status here as images are actually produced. Home and other fitness screens are not part of this review.

## Captured artifacts

These are actual 1080×2400 renders from the isolated Android 36.1 emulator at default font scale. The registration capture shows field validation without submitting credentials. Before captures are still pending; the earlier capture attempt found the original emulator signed in on Home, so no authentication baseline pair is claimed. Initial Android captures exposed status-bar contrast, corrected in the final implementation.
