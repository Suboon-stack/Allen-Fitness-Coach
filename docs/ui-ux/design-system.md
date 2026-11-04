> Historical design record. The selected current palette and reviewed-screen styling are specified in [Midnight Navy + Electric Blue](midnight-theme.md).

# Allen design system — Stage 1

Historical status: initial Home implementation awaiting review at that stage. Later Home and Midnight UI milestones are owner-approved; current results are in the [milestone review](approved-midnight-milestone.md). These are implementation decisions based on the approved brief, not findings from user research.

## Visual foundations

- Primary: forest green `#145C46`; accent: mint `#A8E6CF`.
- Light canvas: `#F7F9F7`; surface: `#FFFFFF`; primary text: `#17221D`.
- The brief's muted `#738078` is unsuitable for some small text on white. Body secondary text uses darker `#59675F` for readability.
- Dark canvas: `#111E17`; surface: `#1B2B23`; primary text: `#E8F0EB`; secondary text: `#B0BDB5`; interactive accent: mint.
- ColorScheme provides semantic colors. Material 3 handles interactive button states. Mint is a supporting surface, not small text on white.
- Typography uses the platform Material font without another dependency: headline 32/24, section title 20, card title 16, body 14, with comfortable line heights. Use Theme text styles rather than screen-local font definitions.

## Components and layout

`lib/fitness/widgets/allen_components.dart` provides AllenCard, AllenButton, AllenSectionTitle, and AllenSpacing. Cards use a 20px radius, thin semantic borders, and no added shadow. Interactive cards use Material ink and keyboard focus. Buttons have a minimum 52px height and expose disabled/loading states.

Spacing tokens: 4, 8, 16, 24, 32px. Home uses a 1040px maximum content width. Feature cards use two columns from 680px and one below. Activity cards use three columns from 560px when text size permits, otherwise one. Content height grows with text; drawer content scrolls.

Home follows device brightness with MediaQuery. Both themes live in AppTheme; no preference storage or theme setting was added. AppTheme.legacyTheme preserves the original theme for screens outside this stage. Main intentionally retains it until those screens are approved for migration. The original Pallete is unchanged.

## States and accessibility

Home displays labeled progress, a retry action on load failure, a first-use prompt for empty activity, and “Not logged” for absent weight. No sample fitness metrics are inserted. Navigation remains available while loading or after an error. Pull to refresh and return navigation refresh the same existing source.

Text scaling and narrow layouts have widget coverage, but execution is blocked by the installed Flutter SDK. Screen-reader behavior, focus traversal, device contrast rendering, and actual mobile layouts still require manual review. No usability study or accessibility certification is claimed.
