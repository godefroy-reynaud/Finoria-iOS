# Finoria

**Finoria** is a native iOS personal-finance tracker for people who want to know exactly where their money goes without handing their data to a third party. It manages multiple styled accounts, records income and expenses with automatic categorization, projects your future balance through planned and recurring transactions, and visualizes spending by category — all stored on-device with SwiftData and synchronized across your Apple devices through your own iCloud account. French-language UI, zero third-party dependencies, zero tracking.

![Swift](https://img.shields.io/badge/Swift-5%20mode%20(concurrency--annotated)-F05138?logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-18.0+-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-007AFF?logo=swift&logoColor=white)
![Dependencies](https://img.shields.io/badge/Dependencies-0-brightgreen)

---

## Features

- **Multi-account management** — unlimited accounts, each with one of 10 visual styles (icon + color) auto-guessed from the account name ("Livret A" → Épargne), editable, resettable, and deletable (cascade)
- **Income & expense transactions** — amount, comment (30 chars max), date, with **automatic categorization** from comment keywords ("essence" → Carburant, "netflix" → Abonnement)
- **32 built-in categories** + **custom categories** per account (name, SF Symbol from a curated grid of 72, custom color)
- **Future ("potential") transactions** — planned expenses/income that don't count toward the current balance until validated (swipe to validate)
- **Recurring transactions** — daily / weekly / monthly / yearly, anchored to the start date (a rent due on the 31st stays on the 31st, clamped only in shorter months); occurrences are generated one month ahead as potential transactions and **auto-validated** when their date passes; pause/resume support
- **Quick shortcuts** — one-tap transaction templates on the home screen, with stacked draggable toast confirmations and haptic feedback
- **Analyses** — interactive donut chart (Swift Charts) of expenses or income by category, month-by-month navigation, tap-to-highlight slices, drill-down to a category's transactions grouped by day
- **Calendar navigation** — browse validated transactions by day / month / year with per-period totals
- **CSV export & import** — RFC 4180-compliant export via the system share sheet (generated off the main thread, on demand), import via the document picker with category re-matching
- **iCloud sync (CloudKit)** — automatic, via SwiftData's CloudKit integration; explicit account-status diagnostics with a user-friendly alert (no account, restricted, quota exceeded, offline…) that the user can dismiss permanently with "Ne plus afficher"
- **Weekly local reminder** — Sunday 20:00 "did you log your purchases?" notification
- **Onboarding** — Apple-style "What's New" welcome sheet on first launch
- Full dark-mode support; graceful full-screen error view if the database cannot be initialized

## Tech Stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 18.0 minimum deployment target) |
| Persistence | SwiftData (`@Model`, `@Query`, `ModelContainer`) |
| Sync | CloudKit via SwiftData `cloudKitDatabase: .automatic` — container `iCloud.com.godefroyinformatique.GDF-app` |
| Charts | Swift Charts (`SectorMark` donut) |
| Concurrency | Swift Concurrency — `@Observable` + `@MainActor` data layer, `async/await`; **Swift 5 language mode** (`SWIFT_VERSION = 5.0`; concurrency annotations are Swift 6-ready but not compiler-enforced yet) |
| Notifications | UserNotifications (local weekly reminder) + CloudKit **silent** sync pushes (`registerForRemoteNotifications`) |
| Logging | `os.log` `Logger` (CSV/calculation services still use `print()`) |
| Third-party packages | **None** (the SPM sections of the project are empty) |
| Language / locale | Swift; UI strings and date formats hardcoded French (`fr_FR`), currency EUR |
| Bundle ID / version | `fr.godefroyinformatique.GDF-app` — version 2.0.0 (build 2010) |

## Architecture

Finoria uses the modern **MV (Model–View) pattern** — there are no ViewModels. SwiftData `@Model` classes are the domain model, SwiftUI views read state directly, and a single `@MainActor @Observable` class, **`AccountsManager`**, is the **only write path**: every insert, update, and delete goes through it, and each mutation ends in an internal `persist()` that calls `modelContext.save()`. Stateless service types (`CalculationService`, `RecurrenceEngine`, `CSVService`, `CloudKitService`, `SwiftDataService`) hold the actual business logic; the manager orchestrates them. `AccountsManager`'s implementation is split across per-domain extension files (`AccountsManager+Accounts/Transactions/CustomCategories/Calculations/Shortcuts/CSV/Recurring.swift`); the core file keeps only the observed state, the lifecycle, and the shared persistence helpers (`persist()`, `firstAccount()`).

**Reads follow two routes.** Account *lists* come straight from SwiftData via `@Query` (lazy, auto-updating — used by `ContentView` and `AccountPickerView`). Everything scoped to the *selected* account (transactions, shortcuts, recurrences, totals) is read through `AccountsManager` helper methods, which all funnel through the computed `selectedAccount` property (a targeted `fetchLimit = 1` fetch keyed on the observed `selectedAccountId`). Because SwiftData's inverse-relationship observation is not reliable enough to drive UI refresh on its own, the manager maintains an observed **`dataVersion` token**: `persist()` and `refreshFromStore()` increment it, and the read helpers touch it during view-body evaluation — so every committed mutation invalidates exactly the views that display manager-derived data. If you ever add a read path that bypasses `selectedAccount`, read `dataVersion` inside it.

**CloudKit is integrated at the container level, not in app code.** `SwiftDataService.makeContainer()` configures `cloudKitDatabase: .automatic`; saving the main context is all that's required to sync. If CloudKit container creation fails (no iCloud account, fresh simulator), a fallback **on-disk** container without CloudKit is used — data is never lost; if *that* also fails, the app shows `DatabaseErrorView` instead of crashing. On foregrounding, `ContentView` calls `refreshFromStore()` (re-validates the selected account, which may have been deleted on another device, and bumps `dataVersion`) and re-runs the recurrence engine. Silent CloudKit pushes are enabled by `AppDelegate.registerForRemoteNotifications()`.

## Project Structure

```
Finoria-iOS/
├── README.md / STRUCTURE_APP.md          # This file / exhaustive per-file code reference
├── Finoria-Info.plist                    # Background modes (remote-notification), encryption exemption
├── Finoria.entitlements                  # Debug: APNs development + iCloud/CloudKit container
├── FinoriaRelease.entitlements           # Release: APNs production + iCloud/CloudKit container
├── Finoria.xcodeproj                     # objectVersion 56 — new files MUST be registered manually
└── Finoria-app/
    ├── FinoriaApp.swift                  # @main — container setup w/ fallback + error screen, env injection
    ├── Notifications.swift               # AppDelegate (push/CloudKit) + NotificationManager (weekly local)
    ├── PrivacyInfo.xcprivacy             # Privacy manifest (UserDefaults, reason CA92.1)
    ├── Localizable.strings               # Localization file (empty since remote announcements were removed)
    ├── LaunchScreen.storyboard           # Launch screen
    ├── Models/
    │   ├── FinoriaSchema.swift           # ⚠️ Versioned schema (V1) + migration plan — change here to evolve structure w/o data loss
    │   ├── Account.swift                 # @Model account + AccountStyle enum (10 styles, name guessing)
    │   ├── Transaction.swift             # @Model transaction + TransactionType enum (+/−)
    │   ├── RecurringTransaction.swift    # @Model recurrence + RecurrenceFrequency + anchor-based occurrence math
    │   ├── WidgetShortcut.swift          # @Model one-tap transaction template
    │   ├── CustomTransactionCategory.swift  # @Model per-account user-defined category
    │   ├── TransactionCategory.swift     # 32-case built-in category enum + keyword auto-detection
    │   ├── AccountsManager.swift         # Central @Observable @MainActor manager — core state, lifecycle, persist()
    │   ├── AccountsManager+Accounts.swift         # Account CRUD
    │   ├── AccountsManager+Transactions.swift     # Transaction CRUD + transactions()
    │   ├── AccountsManager+CustomCategories.swift # Custom category CRUD + CSV re-link
    │   ├── AccountsManager+Calculations.swift     # Totals & filters (delegate to CalculationService)
    │   ├── AccountsManager+Shortcuts.swift        # Widget shortcut CRUD
    │   ├── AccountsManager+CSV.swift              # CSV export snapshot + import
    │   ├── AccountsManager+Recurring.swift        # Recurrence CRUD + processRecurringTransactions()
    │   └── AppStorageKeys.swift          # Centralized UserDefaults key constants
    ├── Services/
    │   ├── SwiftDataService.swift        # ModelContainer factories: CloudKit / local fallback / in-memory preview
    │   ├── CalculationService.swift      # Pure financial math: totals, per-month/year filters, % change
    │   ├── RecurrenceEngine.swift        # Generates/validates recurring transaction instances
    │   ├── CSVService.swift              # RFC 4180 CSV export (off-main, Sendable rows) + import parser
    │   └── CloudKitService.swift         # iCloud account-status diagnostics (user-facing alerts)
    ├── Extensions/
    │   ├── StylableEnum.swift            # Style protocol (icon/color/label) — adopted by AccountStyle & TransactionCategory
    │   ├── AmountFormatting.swift        # compactAmount(_:) — locale-aware compact amount formatter
    │   ├── TransactionGrouping.swift     # [Transaction].groupedByDay() — day-grouping helper
    │   ├── ViewModifiers.swift           # Adaptive background, account-picker toolbar, day headers, currency fmt
    │   ├── ColorHex.swift                # Color ↔ "#RRGGBB" conversion for custom categories
    │   └── DateFormatting.swift          # Date.monthName(_:) French month names
    └── Views/
        ├── ContentView.swift             # Root TabView (5 tabs incl. "+" pseudo-tab), onboarding, CloudKit alert
        ├── WelcomeView.swift             # First-launch feature tour sheet
        ├── NoAccountView.swift           # Empty state when no account is selected
        ├── DatabaseErrorView.swift       # Full-screen error when the DB cannot initialize
        ├── DocumentPicker.swift          # UIDocumentPickerViewController wrapper for CSV import
        ├── Account/                      # AccountCardView, AccountPickerView (@Query), AddAccountSheet
        ├── Components/                   # CurrencyTextField, AccountCategoryPicker, TransactionCategoryPicker,
        │                                 #   StyleIconView, DayGroupedTransactionSections
        ├── Transactions/                 # AddTransactionView, TransactionRow, AddCustomTransactionCategorySheet
        ├── Recurring/                    # AddRecurringTransactionView, RecurringTransactionsGridView
        ├── Widget/                       # AddWidgetShortcutView + Toast/ (ToastData, ToastView, ToastCard)
        └── TabView/
            ├── HomeTabView.swift         # Home tab shell: CSV share (ShareLink+Transferable) & import toolbar
            ├── HomeView.swift            # Balance header, quick cards, shortcuts & recurrence grids, toasts
            ├── Home/                     # HomeComponents (header/cards/toast stack), ShortcutsGridView
            ├── FutureTabView.swift       # Future tab shell
            ├── PotentialTransactionsView.swift  # Potential transaction list w/ validate & delete swipes
            ├── Analyses/                 # AnalysesTabView, AnalysesView, AnalysesPieChart, CategoryBreakdownRow,
            │                             #   CategoryTransactionsView, AnalysesModels (CategoryData, routes)
            └── Calendrier/               # CalendrierMainView/TabView, AllTransactionsView, MonthsView,
                                          #   TransactionsListView, CalendrierRoute
```

## Data Model

All five persisted types are SwiftData `@Model` classes. For CloudKit compatibility, the key Apple constraint is that **relationships must not be required** (to-one relationships should be optional, and relationship minimum counts must stay at 0), and `@Attribute(.unique)` is unsupported. This does **not** mean every stored scalar field (`String`, `Double`, `Bool`, enums, etc.) must be optional; those can stay non-optional when modeled safely (for example with defaults or controlled initialization). The schema is **versioned** (`FinoriaSchemaV1`) and the container is opened with a **migration plan** (`FinoriaMigrationPlan`, with deliberately empty stages) so that additive structural changes migrate existing data automatically instead of discarding it — see *Schema evolution* below.

**Account** is the root entity: an id (UUID), a name (15 chars max), an optional detail line (20 chars max), and a visual style — one of ten `AccountStyle` cases pairing an SF Symbol with a color, guessable from the account name. It owns four cascade-deleting to-many relationships: its transactions, its widget shortcuts, its recurring transactions, and its custom categories. Deleting an account removes everything it contains.

**Transaction** is a single money movement: a signed amount (positive = income, negative = expense), a comment, a built-in category, an optional link to a custom category, and the central "potentiel" flag — true means planned/future (its date may be nil and it is excluded from the current balance), false means validated (counted, dated). A transaction optionally points to the recurring transaction that generated it, and to its owning account. An "importedCategoryName" field remembers a CSV category label that didn't match any existing category, so the transaction can be re-linked automatically when the user later creates a matching custom category. Display helpers resolve the effective label, icon, and color from the custom category when present, otherwise from the built-in one.

**RecurringTransaction** is a template, not a movement: amount, comment, type (income/expense), category or custom category, a frequency (daily, weekly, monthly, yearly), an anchor start date, a "lastGeneratedDate" watermark that prevents regenerating occurrences, and a paused flag. Its generated transactions are linked with a nullify delete rule: deleting a recurrence keeps already-validated history, while its pending potential occurrences are explicitly removed by the engine. Occurrence dates are always computed from the anchor (start date plus n periods), so a monthly recurrence on the 31st clamps in short months without permanently drifting.

**WidgetShortcut** is a one-tap transaction template shown on the home grid: amount, comment, type, and category or custom category, owned by an account. Tapping it creates an immediately-validated transaction dated now.

**CustomTransactionCategory** is a per-account user-defined category: a name, an SF Symbol name, and a hex color string. Transactions referencing it carry the built-in category "other" underneath, so analyses group custom-categorized spending under "Autre". Its transaction links are nullified on deletion.

## Key Flows

**Adding a transaction.** The root `TabView` has a fifth "+" pseudo-tab (`role: .search`); selecting it doesn't navigate — `ContentView.onChange` opens the `AddTransactionView` sheet and snaps the selection back to the previous tab. The form auto-suggests a category from comment keywords as you type (until you pick one manually), validates amount > 0 / non-empty comment / ≤ 999 999 999,99 €, then calls `accountsManager.addTransaction(_:)`. The manager attaches the transaction to `selectedAccount`, inserts it into the `ModelContext`, and `persist()` saves and increments `dataVersion` — which re-renders the balance header, lists, and analyses. If "Transaction future" is toggled, the transaction is created with `potentiel = true` and no date, landing in the Futur tab instead of the balance.

**Recurring transactions.** `processRecurringTransactions()` runs at launch, on every return to foreground, and after creating/updating/resuming a recurrence. It fetches all accounts and hands them to `RecurrenceEngine.processAll`, which for each active recurrence asks `pendingTransactions()` for occurrences within the next month that are newer than the `lastGeneratedDate` watermark. Same-day occurrences are created already validated; future ones are created as potential transactions carrying their planned date. The engine then auto-validates any potential transaction whose date has passed, and the watermark is advanced. Duplicates are prevented twice over: the watermark, plus a per-(recurrence, day) existence check. Pausing or editing a recurrence first strips its pending potential occurrences; editing resets the watermark so the schedule regenerates from the new parameters; resuming sets the watermark to yesterday so generation restarts from today.

**CloudKit sync, first launch, and fallback.** At startup `FinoriaApp` builds the container with CloudKit `.automatic`; if that throws it retries with an on-disk, CloudKit-free configuration (nothing is lost — sync simply stays off), and if *that* also fails the window shows `DatabaseErrorView` with recovery suggestions instead of crashing. On first launch `ContentView` shows the welcome sheet (`hasSeenWelcome` in UserDefaults), auto-selects the first account if none is selected, and runs `CloudKitService.checkAccountStatus()` — any problem (signed out, restricted, quota exceeded, offline) surfaces as a localized alert. Sync itself is implicit: every `modelContext.save()` is pushed by SwiftData, and incoming changes arrive via silent pushes (the `AppDelegate` registers for remote notifications). When the app returns to the foreground, `refreshFromStore()` re-validates the selection — covering both an account deleted from another device and the second-device first launch where accounts arrive *after* `.onAppear` — and bumps `dataVersion` so all lists reflect the merged changes. The last selected account ID persists in UserDefaults (a UI preference, deliberately not synced).

## Development Notes

**Concurrency.** `AccountsManager` is `@MainActor @Observable`; all model reads/writes happen on the main actor (required by `ModelContainer.mainContext`). The one deliberately off-main code path is CSV export: `csvExportSnapshot()` snapshots transactions into `Sendable` `CSVService.ExportRow` values on the main actor, then the `Transferable` `FileRepresentation` closure builds and writes the file in the background — keeping share-sheet presentation freeze-free. The project compiles in **Swift 5 language mode**: the `@MainActor`/`Sendable` annotations are in place but not compiler-verified; enabling `SWIFT_STRICT_CONCURRENCY = complete` is the recommended next step before moving to Swift 6 mode.

**Schema evolution (zero data loss).** The data structure can change in future updates **without ever losing user data** (on-device *or* in iCloud), because persistence is built on SwiftData's versioned-schema + migration-plan mechanism. The single source of truth is [`Finoria-app/Models/FinoriaSchema.swift`](Finoria-app/Models/FinoriaSchema.swift): it defines `FinoriaSchemaV1` (the current schema), `FinoriaMigrationPlan` (versions `[V1]` with **deliberately empty `stages`**), and the `FinoriaCurrentSchema = FinoriaSchemaV1` alias that `SwiftDataService` feeds into every `ModelContainer`. Rules when you change the structure:

1. **Additive changes are easy and safe** — adding a property *with a default value*, a new `@Model`, or an *optional* relationship/inverse is CloudKit-compatible and migrates **automatically**. Just edit the `@Model`s; do **not** add a schema version or a migration stage.
2. **⚠️ Never add a `MigrationStage` while the `VersionedSchema`s share the same live `@Model` types.** They produce identical schema checksums, so a `.lightweight(V1 → V2)` stage throws in `NSLightweightMigrationStage` and **crashes the app on launch** (this exact regression shipped in build 286 and was reverted). A real staged migration first requires freezing per-version copies of the model definitions.
3. **CloudKit only allows additive schema changes.** You cannot delete or rename a field server-side. To "rename", add the new field, migrate the data, and keep the old field (deprecated) rather than removing it.
4. **Apple CloudKit rule to remember:** for SwiftData sync, relationships must be optional/non-required; scalar properties do not all need to be optional.
5. **Test on a device that already holds old-version data** before publishing — it must launch and keep every record.
6. **Outside the migration plan:** never rename/remove a shipped enum `case` (its `rawValue` is persisted — add cases only), and never change the CloudKit container ID or bundle ID after release.

The full step-by-step procedure and a ready-to-copy V2 template live in the header comment of `FinoriaSchema.swift`; each `@Model` also carries a one-line reminder pointing back to it.

**Running the project.**
- Open `Finoria.xcodeproj`, scheme **Finoria**, any iOS 18.0+ simulator or device (`⌘R`).
- Full CloudKit sync needs a device/simulator signed into iCloud and a provisioning profile carrying the `iCloud.com.godefroyinformatique.GDF-app` container; without it the app silently runs on the local fallback container (expected on fresh simulators).
- Debug builds sign with `Finoria.entitlements` (APNs development); Release/App Store builds with `FinoriaRelease.entitlements` (APNs production).
- ⚠️ The project file uses the **old format (`objectVersion = 56`)** — files added outside Xcode must be manually registered in `project.pbxproj` (PBXFileReference + PBXBuildFile + group children + build phase) or they will silently not be compiled/bundled.
- SwiftUI previews work without iCloud via `AccountsManager.preview` (in-memory container).

**Known limitations** (the code contains no `TODO`/`FIXME`/`HACK` markers; these come from the 2026-06-12 pre-publication audit):
- CSV **import has no deduplication** — importing the same file twice duplicates every transaction.
- UI language, date formats, and currency are hardcoded French/EUR (`fr_FR`); the only localized strings are the two CloudKit push keys in `Localizable.strings`.
- `CSVService` and `CalculationService` log with `print()` instead of `os.log`.
- Analyses group custom-category spending under the built-in "Autre" slice (custom categories are not first-class in the chart).
- Both test targets are empty Xcode templates — there is no automated test coverage.
- The home header's monthly "% change" compares net totals (income + expenses) of the current vs previous month, not balances — by design, but worth knowing.

---

📚 Complete per-file technical reference → [STRUCTURE_APP.md](STRUCTURE_APP.md)

*Personal project — all rights reserved.*
