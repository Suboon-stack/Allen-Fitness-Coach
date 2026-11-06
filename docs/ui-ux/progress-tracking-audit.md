# Progress Tracking audit and approved-reference interpretation

Milestone started on 5 November 2026 from clean, synchronized `main` at `e50d1e5`, on `feature/progress-tracking-redesign`. The initial implementation stage prohibited publication before owner approval. The owner subsequently authorized milestone finalization and a normal merge on 6 November 2026, subject to validation; the audit findings below describe the pre-implementation code.

## Reference and design direction

The local reference `Dark Navy Fitness Progress Dashboard.png` matches the owner's Timeline Style/interactive-chart brief: Your Journey mountain banner, dated weight chart with 7D/30D/3M/1Y controls, compact key metrics, vertical activity timeline, and bottom navigation. It is a concept, not evidence of implemented Allen functionality. Reference numbers, green weight-loss claims, calorie-burn values and achievements must not become hardcoded app data. Reuse the centralized Midnight palette, including electric blue/mint-free secondary blue; use an original lightweight mountain vector, not a raster mockup.

Retain Allen's four Home/Workouts/Nutrition/Progress navigation destinations. Mirror these on Progress rather than adding the reference's Profile tab or replacing the app's navigation architecture. Home returns through the existing route stack; feature shortcuts open existing pages and refresh Progress on return.

## Confirmed code findings before implementation

| Area | Finding and consequence |
| --- | --- |
| Weight writes | `ProgressRepository.addWeightEntry` discards the passed ID/user/date/notes and calls `addWeight(double)`, storing only weight and current date. Stable editing/deletion, historical dates and account ownership are unavailable. |
| Weight reads | Reads all accounts, assigns missing owner metadata to the caller, fabricates missing dates/zero values, and returns empty history on errors. The latest-100 cap can omit measurements from longer chart ranges. |
| Weight deletion | Stored entries lack IDs; deletion cannot reliably identify a selected legacy record. |
| Statistics | Reads raw workouts/meals across accounts. Food calories are multiplied by five and labeled calories burned, without a supporting data source. The new Progress view must not do this. |
| Chart/filtering | X positions are list indices, not actual dates. Period chips change selection but do not filter the list. Labels are hidden and single-point/empty datasets need explicit presentation. |
| UI state | No useful error/retry state; missing session may leave loading active; weight submission lacks duplicate, lifecycle and identity guards. Three older tabs fragment the requested unified timeline layout. |
| Workouts | Stored UUID, `userId`, name, duration, completed flag, activity `date` and original `createdAt` exist. Completion updates the activity date. Only currently completed records are evidence of completion; no repeated-session archive or verified calorie-burn measurements exist. General workout reads/counts still share data, so Progress needs an ownership-filtered read projection without redesigning Workouts. |
| Meals | Existing MealRepository filters owners and validates values. Dated meal records support nutrition totals/timeline; generated suggestions are not intake. Scanner AI-estimate provenance is retained in notes. |
| Water | `water_YYYY-MM-DD` totals are device-wide, without ownership, individual timestamps or entries. They cannot become personal water history or per-entry timeline events. Defer ownership migration and show an honest unavailable state in personal Progress. |
| Goals | An owned stored profile can provide calorie/protein/carb/fat targets. No stored weight target or workout-session target exists. Do not invent goals or percentages. A fourth metric may use protein only with real logged nutrition and a valid stored protein goal. |
| Dependencies | `fl_chart` 0.69.2, Intl, UUID, SharedPreferences and the existing theme/components suffice. No new dependency is proposed. |

## Storage decision requiring approval

Requested explicitly in chat before persistence edits: add `id`, `userId`, `createdAt` and optional `notes` to **new** records in the existing `weights` JSON list, alongside weight/date, using the existing WeightEntry model. Preserve legacy and foreign records byte-for-field in the list; do not silently assign their ownership or migrate them. Unknown-owner records must not be presented as the signed-in user's personal history. Stable IDs permit guarded editing/deletion and duplicate-safe retries for new entries.

The shared weight reader also serves Home/Profile. Enforcing ownership there will stop those screens displaying unowned/foreign weights as personal, while retaining every stored record. This dependency was explained in the approval request. Water ownership changes remain deferred. The owner explicitly approved this additive metadata/account-filtering plan, including checking ownership during saving/editing, preserving all legacy records and deferring water migration. No bulk migration or account reassignment is authorized.

## Verification boundaries

Repository logic and UI behavior above are code findings. Real Android chart gestures, keyboard/safe-area behavior, native storage acknowledgment/restarts, TalkBack and appearance still need implementation tests and then owner phone review. No Progress device approval, research study or usability result is claimed.
