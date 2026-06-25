# Finoria — Complete Code Structure Reference

*Last updated: 2026-06-25*

This file documents **every Swift file** in the project so a developer or AI can understand any class, function, or view without opening the source. Companion overview: [README.md](README.md).

Project facts: iOS 18.0+, SwiftUI + SwiftData + CloudKit, Swift 5 language mode (concurrency-annotated), zero third-party dependencies, French UI (`fr_FR`). The Xcode project uses the old format (`objectVersion = 56`): **files added outside Xcode must be registered manually in `project.pbxproj`** (PBXFileReference + PBXBuildFile + group children + Sources/Resources phase) or they silently won't build/bundle.

---

## App root

---
**`Finoria-app/FinoriaApp.swift`**

**Purpose:** App entry point — builds the SwiftData/CloudKit container (with on-disk fallback and graceful error screen) and injects `AccountsManager` into the environment.

**Type:** `@main struct FinoriaApp: App`

**Dependencies:** SwiftDataService, AccountsManager, ContentView, DatabaseErrorView, NotificationManager, CloudKitService, AppDelegate, os.log.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| logger | static Logger | os.log logger, category "FinoriaApp" |
| appDelegate | @UIApplicationDelegateAdaptor(AppDelegate.self) | Bridges push-notification callbacks |
| modelContainer | ModelContainer? | Shared container; nil if init failed twice |
| initErrorMessage | String? | Error text when both container creations failed |
| accountsManager | @State AccountsManager? | The single data manager; nil without a container |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init | — | — | Tries `makeContainer()` (CloudKit), falls back to `makeFallbackContainer()` (local disk); on double failure stores `initErrorMessage` instead of crashing. On success: creates AccountsManager from `mainContext`, requests notification permission, schedules the weekly reminder |
| body | — | some Scene | `WindowGroup`: if container+manager exist → `ContentView().environment(manager).modelContainer(container)`; otherwise `DatabaseErrorView` |

**Notes:** `.modelContainer` is applied on the view (not the Scene) because the container is optional. Notifications are only set up when the database is functional.

---
**`Finoria-app/Notifications.swift`**

**Purpose:** Push-notification plumbing (required for CloudKit silent sync) and the weekly local reminder.

**Type:** `class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate` + `struct NotificationManager` + private file-scope `notifLogger`.

**Dependencies:** UserNotifications, UIKit (via SwiftUI), os.log. Referenced by FinoriaApp.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| NotificationManager.shared | static NotificationManager | Singleton accessor |
| notificationIdentifier | String (private) | Fixed id "WeeklyNotification" to avoid duplicates |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| application(_:didFinishLaunchingWithOptions:) | app, options | Bool | Sets UNUserNotificationCenter delegate, calls `registerForRemoteNotifications()` (enables CloudKit silent pushes) |
| userNotificationCenter(_:willPresent:withCompletionHandler:) | — | — | Shows banners/sound/badge even in foreground |
| application(_:didRegisterForRemoteNotificationsWithDeviceToken:) | token | — | Logs truncated token |
| application(_:didFailToRegisterForRemoteNotificationsWithError:) | error | — | Logs failure |
| application(_:didReceiveRemoteNotification:fetchCompletionHandler:) | userInfo, handler | — | CloudKit silent push received; SwiftData merges automatically; completes `.newData` |
| requestNotificationPermission | — | — | Requests alert/badge/sound authorization |
| listScheduledNotifications | — | — | Logs pending requests — **dead code, never called** |
| scheduleWeeklyNotificationIfNeeded | — | — | Schedules the weekly reminder if absent or stale (re-checks title "Rappel - Finoria") |
| scheduleWeeklyNotification (private) | — | — | Calendar trigger: Sunday (weekday 1) 20:00, repeating |
| resetNotifications | — | — | Removes all pending local notifications |

**Notes:** The `AppDelegate` only registers for remote notifications to enable CloudKit **silent** sync pushes — there is no longer any user-facing remote announcement feature (it was removed; see `ARCHIVE_notifications-distantes.md`). `Localizable.strings` therefore holds no `CK_ANNOUNCEMENT_*` keys anymore.

---

## Models/

---
**`Finoria-app/Models/FinoriaSchema.swift`**

**Purpose:** ⚠️ Versioned-schema + migration infrastructure — the single control point for evolving the data structure **without losing any user data** (on device or in iCloud).

**Type:** `enum FinoriaSchemaV1: VersionedSchema`, `enum FinoriaMigrationPlan: SchemaMigrationPlan`, and `typealias FinoriaCurrentSchema = FinoriaSchemaV1`.

**Dependencies:** SwiftData; the five @Model types (referenced, not redefined).

**Members:**
| Name | Kind | Description |
|------|------|-------------|
| FinoriaSchemaV1.versionIdentifier | static Schema.Version | `1.0.0` — frozen snapshot identifier of the currently shipped structure |
| FinoriaSchemaV1.models | static [any PersistentModel.Type] | The five models composing version 1 |
| FinoriaMigrationPlan.schemas | static [any VersionedSchema.Type] | Ordered list of all schema versions (only V1 today) |
| FinoriaMigrationPlan.stages | static [MigrationStage] | Migration steps between successive versions (empty today) |
| FinoriaCurrentSchema | typealias | Always points to the latest version; the one line to flip when adding V2 |

**Notes:** Consumed by `SwiftDataService`, which builds every `ModelContainer` from `FinoriaCurrentSchema` + `FinoriaMigrationPlan`. The file header documents the full migration procedure (additive = `.lightweight`, complex = `.custom` with `willMigrate`/`didMigrate`), the CloudKit additive-only constraint, and a copy-paste V2 template. **Golden rule: never edit a shipped `FinoriaSchemaVx`; add a new version + stage instead.** Each `@Model` carries a one-line reminder pointing here.

---
**`Finoria-app/Models/Account.swift`**

**Purpose:** Root SwiftData entity for a financial account, plus its visual style enum.

**Type:** `enum AccountStyle: String, Codable, CaseIterable, Identifiable, StylableEnum` + `@Model final class Account`.

**Dependencies:** SwiftData, SwiftUI (Color), StylableEnum protocol, Transaction, WidgetShortcut, RecurringTransaction, CustomTransactionCategory.

**Properties (Account):**
| Name | Type | Description |
|------|------|-------------|
| id | UUID (default UUID()) | Stable identifier (not `@Attribute(.unique)` — CloudKit forbids it) |
| name | String | Account name (UI caps at 15 chars) |
| detail | String | Optional subtitle (UI caps at 20 chars) |
| style | AccountStyle | One of 10 icon+color styles |
| transactions | [Transaction] | `.cascade` delete, inverse `Transaction.account` |
| widgetShortcuts | [WidgetShortcut] | `.cascade`, inverse `WidgetShortcut.account` |
| recurringTransactions | [RecurringTransaction] | `.cascade`, inverse `RecurringTransaction.account` |
| customTransactionCategories | [CustomTransactionCategory] | `.cascade`, inverse `CustomTransactionCategory.account` |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init | id, name, detail, style? | — | style nil → `AccountStyle.guessFrom(name:)` |
| AccountStyle.icon / .color / .label | — | String/Color/String | Visual triplet per case (bank, savings, investment, business, travel, grocery, student, family, property, entertainment) |
| AccountStyle.guessFrom | name: String | AccountStyle | Keyword matching on the lowercased name ("livret"→savings, "pea"→investment, …), default `.bank` |

**Notes:** Deleting an account cascades to everything it owns.

---
**`Finoria-app/Models/Transaction.swift`**

**Purpose:** SwiftData entity for a single money movement (validated or planned), plus the income/expense type enum.

**Type:** `enum TransactionType: String, CaseIterable, Codable, Identifiable` ("+"/"−") + `@Model final class Transaction`.

**Dependencies:** SwiftData, SwiftUI (Color), TransactionCategory, CustomTransactionCategory, RecurringTransaction, Account.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| id | UUID | Identifier |
| amount | Double | Signed: positive = income, negative = expense |
| comment | String | User label (UI caps at 30 chars) |
| potentiel | Bool | `true` = planned/future (excluded from balance), `false` = validated |
| date | Date? | nil allowed while potential; set on validation |
| category | TransactionCategory | Built-in category (`.other` when a custom one is used) |
| importedCategoryName | String? | Unmatched CSV category label, kept for later re-linking |
| account | Account? | Owner (inverse of Account.transactions) |
| sourceRecurringTransaction | RecurringTransaction? | Generating recurrence, nil if manual |
| customCategory | CustomTransactionCategory? | Optional user-defined category |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init | id, amount, comment, potentiel, date, category, sourceRecurringTransaction, customCategory, importedCategoryName | — | All defaulted except amount/comment |
| validate | at date: Date | — | Sets `potentiel = false` and the date (in-place mutation tracked by SwiftData) |
| modify | optionals for every field (double-optionals for nullables) | — | Bulk in-place update — **dead code, never called** |
| displayCategoryLabel / Icon / Color | — | String/String/Color | Resolve from customCategory if set, else from built-in category |

---
**`Finoria-app/Models/RecurringTransaction.swift`**

**Purpose:** SwiftData entity for a recurring-transaction template and the anchor-based occurrence math.

**Type:** `enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable` (daily/weekly/monthly/yearly with `label`/`shortLabel`) + `@Model final class RecurringTransaction`.

**Dependencies:** SwiftData, SwiftUI (Color), TransactionType, TransactionCategory, CustomTransactionCategory, Transaction, Account.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| id, amount, comment | UUID, Double, String | Template identity and content (amount stored positive) |
| type | TransactionType | income/expense; sign applied at generation |
| category / customCategory | TransactionCategory / CustomTransactionCategory? | Category pair (custom forces built-in `.other`) |
| frequency | RecurrenceFrequency | Period |
| startDate | Date | **Anchor** — every occurrence is computed from it |
| lastGeneratedDate | Date? | Watermark to avoid regenerating occurrences |
| isPaused | Bool | Paused recurrences generate nothing |
| account | Account? | Owner |
| generatedTransactions | [Transaction] | `.nullify` delete, inverse `Transaction.sourceRecurringTransaction` — history survives recurrence deletion |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init | template fields | — | category nil → `TransactionCategory.guessFrom(comment:type:)`; custom category forces `.other` |
| occurrences | from: Date, to: Date | [Date] | All occurrence dates in the range. Each is `startDate + n×unit` **from the anchor** — never chained from the previous date, so a monthly recurrence on the 31st clamps in February but returns to the 31st in March (no permanent drift) |
| occurrenceDate (private) | at index: Int, calendar | Date? | n-th occurrence per frequency |
| pendingTransactions | — | [(date: Date, transaction: Transaction)] | Occurrences within the next month, newer than the watermark. Same-day → created validated; future → potential with planned date |
| displayCategoryIcon / Color | — | String/Color | Custom-aware visual resolution |

**Notes:** The transactions returned by `pendingTransactions()` are *not yet inserted*; `RecurrenceEngine` decides insertion and updates the watermark.

---
**`Finoria-app/Models/WidgetShortcut.swift`**

**Purpose:** SwiftData entity for a one-tap transaction template displayed on the home grid.

**Type:** `@Model final class WidgetShortcut`

**Dependencies:** SwiftData, SwiftUI (Color), TransactionType, TransactionCategory, CustomTransactionCategory, Account.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| id, amount, comment | UUID, Double, String | Template content (amount stored positive; UI caps comment at 15) |
| type | TransactionType | Determines sign at execution |
| category / customCategory | TransactionCategory / CustomTransactionCategory? | Custom forces built-in `.other` |
| account | Account? | Owner |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init | template fields | — | category nil → keyword guess from comment |
| displayCategoryIcon / Color | — | String/Color | Custom-aware visual resolution |

---
**`Finoria-app/Models/CustomTransactionCategory.swift`**

**Purpose:** SwiftData entity for a per-account user-defined transaction category.

**Type:** `@Model final class CustomTransactionCategory`

**Dependencies:** SwiftData, SwiftUI, ColorHex extension.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| id | UUID | Identifier |
| name | String | Display name (UI caps at 15; uniqueness enforced in UI via normalized comparison) |
| symbol | String | SF Symbol name (default "tag.fill") |
| colorHex | String | "#RRGGBB" (default "#8E8E93") |
| account | Account? | Owner |
| transactions | [Transaction] | `.nullify` delete, inverse `Transaction.customCategory` |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| resolvedColor | — | Color | `Color(finoriaHex: colorHex)` |

---
**`Finoria-app/Models/TransactionCategory.swift`**

**Purpose:** The 32-case built-in category enum shared by transactions, shortcuts, and recurrences, with keyword-based auto-detection.

**Type:** `enum TransactionCategory: String, Codable, CaseIterable, Identifiable, StylableEnum`

**Dependencies:** SwiftUI (Color), StylableEnum protocol, TransactionType.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| allCases | static [TransactionCategory] | **Custom display order** (income/expense generics first, then by theme) — overrides the synthesized order |
| id | String | rawValue |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| icon / color / label | — | String/Color/String | Visual triplet for each of the 32 cases (salary, income, freelance, bonus, rent, utilities, home, subscription, phone, insurance, food, grocery, coffee, fuel, transport, car, loan, savings, investment, tax, shopping, party, sport, travel, culture, family, health, gift, education, pet, expense, other) |
| guessFrom | comment: String, type: TransactionType | TransactionCategory | ~30 French keyword rules ("loyer"→rent, "netflix"→subscription, "leclerc"→grocery…); falls back to `.income`/`.expense` per type |

**Notes:** `guessFrom` is a long if-chain (~120 lines) — flagged in the audit as a candidate for a keyword-table refactor.

---
**`Finoria-app/Models/AccountsManager.swift`** (+ 7 per-domain extension files)

**Purpose:** Central `@Observable` data manager — the **single write path** to SwiftData and the read funnel for selected-account data.

**Type:** `@MainActor @Observable class AccountsManager`

**Organisation:** the class is split for readability across one core file + 7 same-module extension files (the public API is unchanged — callers don't see the split):
| File | Holds |
|------|-------|
| `AccountsManager.swift` | observed state (`selectedAccountId`, `dataVersion`, `selectedAccount`…), `init`, `preview`, lifecycle (`refreshFromStore`, `saveData`), shared helpers `persist()` / `firstAccount()` / `normalizeCategoryName` |
| `AccountsManager+Accounts.swift` | `addAccount` / `deleteAccount` / `updateAccount` / `resetAccount` |
| `AccountsManager+Transactions.swift` | `addTransaction` / `deleteTransaction` / `validateTransaction` / `updateTransaction` / `transactions()` |
| `AccountsManager+CustomCategories.swift` | custom-category CRUD + private `relinkImportedTransactions` |
| `AccountsManager+Calculations.swift` | totals, available years, % change, status/period filters (all delegate to `CalculationService`) |
| `AccountsManager+Shortcuts.swift` | widget-shortcut CRUD |
| `AccountsManager+CSV.swift` | `csvExportSnapshot` / `importCSV` + private `resolveCustomCategory` |
| `AccountsManager+Recurring.swift` | recurrence CRUD + `processRecurringTransactions` |

`persist()`, `firstAccount()` and the `logger` are `internal` (not `private`) so the extensions can reach them; `relinkImportedTransactions` and `resolveCustomCategory` stay `private` inside the file that uses them.

**Dependencies:** SwiftData (ModelContext, FetchDescriptor), Observation, os.log, Account, Transaction, WidgetShortcut, RecurringTransaction, CustomTransactionCategory, RecurrenceEngine, CalculationService, CSVService, AppStorageKeys, SwiftDataService (preview).

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| logger | static Logger | Category "AccountsManager" |
| modelContext | let ModelContext | Injected at init (`mainContext` in production) |
| selectedAccountId | UUID? (observed) | Current selection; `didSet` persists to UserDefaults (`AppStorageKeys.lastSelectedAccountId`) |
| lastPersistenceError | String? (observed) | Last save/fetch error message (not currently surfaced by any view) |
| dataVersion | private(set) Int (observed) | **Invalidation token** — incremented by `persist()` and `refreshFromStore()`; read by the read helpers so views refresh after every committed mutation (SwiftData inverse-relationship observation alone is unreliable) |
| selectedAccount | Account? (computed) | Reads `dataVersion` + `selectedAccountId`, then `fetchLimit = 1` fetch by id. Funnel for all selected-account reads |
| preview | static AccountsManager | In-memory container instance for SwiftUI previews |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init | modelContext | — | Stores context, restores `selectedAccountId` from UserDefaults |
| persist (private) | — | — | `modelContext.save()` with do/catch + logging, then `dataVersion += 1` |
| firstAccount (private) | — | Account? | First account by name (fetchLimit 1) — selection fallback |
| saveSelectedAccountId / loadSelectedAccountId (private) | — | — / UUID? | UserDefaults round-trip of the selection |
| addAccount / deleteAccount / updateAccount / resetAccount | account (+fields) | — | CRUD; delete cascades and re-selects the first remaining account (or nil); reset deletes all the account's transactions |
| addTransaction | Transaction | — | Attaches to `selectedAccount`, inserts, persists |
| deleteTransaction / validateTransaction | Transaction | — | Delete; or `validate(at: Date())` + persist |
| updateTransaction | tx, amount, comment, potentiel, date, category, customCategory | — | In-place field update; clears `importedCategoryName` when a custom category is set |
| customTransactionCategories / customTransactionCategory(with:) | — / UUID | [CustomTransactionCategory] / optional | Selected account's custom categories |
| addCustomTransactionCategory / updateCustomTransactionCategory / deleteCustomTransactionCategory | name, symbol, colorHex (+category) | optional created / — / — | CRUD; add/update re-link CSV-imported transactions whose stored label matches (normalized) |
| transactions | — | [Transaction] | `selectedAccount?.transactions ?? []` |
| totalNonPotential / totalPotential | for account | Double | Delegates to CalculationService; reads `dataVersion` (these receive @Query-supplied accounts in the picker) |
| availableYears / totalForYear / totalForMonth / monthlyChangePercentage | (year/month) | [Int]/Double/Double/Double? | Delegations over `transactions()` |
| potentialTransactions / validatedTransactions | (year?, month?) | [Transaction] | Filter delegations |
| getWidgetShortcuts / addWidgetShortcut / deleteWidgetShortcut / updateWidgetShortcut | shortcut (+fields) | — | Shortcut CRUD on selected account |
| csvExportSnapshot | — | (rows: [CSVService.ExportRow], accountName: String)? | Sendable snapshot of the selected account's validated, non-recurrence-generated transactions for off-main CSV generation; nil if no account/empty |
| importCSV | from URL | Int | Parses via CSVService, re-links known custom-category labels (creating the category if absent), inserts into selected account, persists; returns count |
| getRecurringTransactions / addRecurringTransaction / deleteRecurringTransaction / updateRecurringTransaction / pauseRecurringTransaction / resumeRecurringTransaction | recurring (+fields) | — | Recurrence CRUD. Delete/update/pause first strip pending potential occurrences (engine); update resets the watermark; resume sets watermark to yesterday and reprocesses |
| processRecurringTransactions | — | — | Fetches all accounts, runs `RecurrenceEngine.processAll`; persists if anything changed |
| saveData | — | — | Public persist passthrough — **dead code, never called** |
| refreshFromStore | — | — | Foreground hook: if `selectedAccount == nil` selects `firstAccount()` (covers CloudKit-deleted selection AND second-device first delivery), then bumps `dataVersion` |
| relinkImportedTransactions (private) | in account, to customCategory | — | Attaches transactions whose `importedCategoryName` matches the category name (normalized) |
| normalizeCategoryName | static, value: String | String | Canonical trim + case/diacritic-insensitive folding — also used by TransactionCategoryPicker |

**Notes:** Split across one core file + 7 per-domain extensions (see the Organisation table above) — the core file is now ~200 lines. If you add a read helper that does **not** go through `selectedAccount`, read `dataVersion` inside it or its views won't refresh.

---
**`Finoria-app/Models/AppStorageKeys.swift`**

**Purpose:** Centralized UserDefaults/@AppStorage key constants (typo-proof).

**Type:** Caseless `enum AppStorageKeys` (namespace).

**Dependencies:** Foundation. Used by AccountsManager, ContentView.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| lastSelectedAccountId | static String "lastSelectedAccountId" | Selected account UUID (UI preference, not synced) |
| hasSeenWelcome | static String "hasSeenWelcome" | Welcome sheet shown once |
| hasSeenICloudWarning | static String "hasSeenICloudWarning" | User tapped "Ne plus afficher" on the iCloud diagnostics alert — suppresses it permanently |

**Methods / Computed vars:** none.

---

## Services/

---
**`Finoria-app/Services/SwiftDataService.swift`**

**Purpose:** ModelContainer factory — production (CloudKit), fallback (local disk), and preview (in-memory) configurations.

**Type:** Caseless `enum SwiftDataService`.

**Dependencies:** SwiftData; the five @Model types.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| models | static [any PersistentModel.Type] | Delegates to `FinoriaCurrentSchema.models` (single source of truth) |
| currentSchema (private) | static Schema | `Schema(versionedSchema: FinoriaCurrentSchema.self)` — shared by all three factories so the version (and migration plan) always applies |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| makeContainer | — | throws ModelContainer | On-disk, `cloudKitDatabase: .automatic`, **`migrationPlan: FinoriaMigrationPlan`** — production path |
| makeFallbackContainer | — | throws ModelContainer | On-disk, `cloudKitDatabase: .none`, same migration plan — data preserved, no sync |
| makePreviewContainer | — | throws ModelContainer | In-memory, no CloudKit, same migration plan — previews/tests |

**Notes:** Every container is built from the versioned schema + `FinoriaMigrationPlan` ([`FinoriaSchema.swift`](Finoria-app/Models/FinoriaSchema.swift)) — this is what guarantees zero data loss across structural changes. CloudKit prerequisites documented in the header (iCloud + Push + Background Modes capabilities; no `@Attribute(.unique)` anywhere).

---
**`Finoria-app/Services/CalculationService.swift`**

**Purpose:** Pure, stateless financial math over transaction arrays — never mutates anything.

**Type:** `struct CalculationService` (all static).

**Dependencies:** Foundation; Transaction.

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| totalNonPotential / totalPotential | transactions | Double | Sum of validated / potential amounts |
| availableYears | transactions | [Int] | Distinct years among validated, sorted ascending |
| totalForYear / totalForMonth | year (+month), transactions | Double | Validated sums per period; dateless validated transactions are skipped with a `print` warning |
| monthlyChangePercentage | transactions | Double? | Current vs previous month net total (handles January→December rollover); nil when previous month is 0 |
| potentialTransactions / validatedTransactions | transactions (+year?, month?) | [Transaction] | Status filters with optional period filters |

**Notes:** Logs with `print("[WARN]…")` instead of os.log (known limitation).

---
**`Finoria-app/Services/RecurrenceEngine.swift`**

**Purpose:** Materializes recurring-transaction templates into actual transactions and auto-validates past-due potentials.

**Type:** `struct RecurrenceEngine` (all static).

**Dependencies:** SwiftData (ModelContext), Account, RecurringTransaction, Transaction.

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| processAll | accounts: [Account], context | @discardableResult Bool | For each active recurrence: inserts `pendingTransactions()` not already present (per-(recurrence, day) existence check), advances `lastGeneratedDate` to the newest generated date. Then auto-validates any potential transaction whose date ≤ today. Returns whether anything changed |
| removePotentialTransactions | for recurring, context | — | Deletes the recurrence's still-potential generated transactions (used on delete/update/pause) |

**Notes:** Never saves — `AccountsManager` persists after each call.

---
**`Finoria-app/Services/CSVService.swift`**

**Purpose:** RFC 4180-compliant CSV export and import of transactions.

**Type:** `struct CSVService` (all static) + nested `struct ExportRow: Sendable`.

**Dependencies:** Foundation; Transaction, TransactionCategory (import side).

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| ExportRow | nested struct (date?, amount, comment, potentiel, categoryLabel) | Sendable snapshot of one transaction — lets generation run off the main actor |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| generateCSV | rows: [ExportRow], accountName | URL? | Sorts by date desc, writes header `Date,Type,Montant,Commentaire,Statut,Catégorie` + one escaped line per row to a temp file `{account}_transactions_{timestamp}.csv`; nil if empty or write fails |
| escapeCSVField (private) | field | String | Quotes fields containing `,` `"` or newlines; doubles inner quotes |
| importCSV | from URL | [Transaction] | Security-scoped read, skips header, parses each line; columns: date `dd/MM/yyyy` or "N/A", type "Revenu"/"Dépense" (sign), amount, comment, status "Potentielle"/"Validée", optional category label (unknown labels stored in `importedCategoryName`). Returns unattached Transaction instances |
| parseCSVLine (private) | line | [String] | Character-by-character RFC 4180 field splitter (quoted fields, `""` escapes) |

**Notes:** Date formatter created once per call (not per line). Line-based parsing cannot reassemble newlines inside quoted fields — impossible from app-generated data (single-line text fields). Import performs **no deduplication** (known limitation). Logs with `print`.

---
**`Finoria-app/Services/CloudKitService.swift`**

**Purpose:** iCloud account diagnostics only — produces user-facing status messages so the app can warn when iCloud sync won't work. (The former public-database "Announcements" push subscription was removed; see `ARCHIVE_notifications-distantes.md`.)

**Type:** Caseless `enum CloudKitService` + nested `enum CloudKitStatus`.

**Dependencies:** CloudKit, os.log.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| logger | static Logger | Category "CloudKitService" |
| container | static CKContainer | `iCloud.com.godefroyinformatique.GDF-app` (frozen — never change after release) |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| checkAccountStatus | — | async CloudKitStatus | Maps `CKContainer.accountStatus()` (available/noAccount/restricted/couldNotDetermine/temporarilyUnavailable) and verifies container access when available |
| verifyContainerAccess (private) | — | async CloudKitStatus | `userRecordID()` probe; maps CKError codes (network, auth, quota, rate-limit) to actionable statuses |
| CloudKitStatus.userMessage / .alertTitle / .isAvailable | — | String/String/Bool | French user-facing alert content |

---

## Extensions/

---
**`Finoria-app/Extensions/StylableEnum.swift`**

**Purpose:** The shared "stylable enum" protocol (icon / color / label) factoring out the visual representation common to `AccountStyle` and `TransactionCategory`. *(The picker views, `StyleIconView` and `compactAmount` that used to live here have been extracted — see `Views/Components/` and the two new entries below.)*

**Type:** `protocol StylableEnum: RawRepresentable, CaseIterable, Identifiable, Codable where RawValue == String` + default `extension { var id }`.

**Dependencies:** SwiftUI (Color).

**Key members:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| StylableEnum | — | protocol | Requires `icon: String`, `color: Color`, `label: String`; default `id = rawValue`. Adopted by AccountStyle and TransactionCategory |

---
**`Finoria-app/Extensions/AmountFormatting.swift`**

**Purpose:** Compact, locale-aware amount formatter (extracted from StylableEnum.swift).

**Type:** global `func compactAmount(_:) -> String`.

**Dependencies:** Foundation.

| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| compactAmount | value: Double | String | Locale-aware compaction: 2 850 → "2850", 2 850 000 → "2,85M"; suffixes k/M/G; trims trailing zeros. Creates a NumberFormatter per call (per-call mutation is value-dependent) |

---
**`Finoria-app/Extensions/TransactionGrouping.swift`**

**Purpose:** Day-grouping helper for transaction lists — the single source of the logic formerly duplicated in AllTransactionsView and CategoryTransactionsView.

**Type:** `extension Array where Element == Transaction`.

**Dependencies:** Foundation; Transaction.

| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| groupedByDay | — | [(date: Date, transactions: [Transaction])] | Groups by `startOfDay`, days sorted descending; dateless transactions fall under `Date.distantPast`. Preserves intra-day order from the source array (callers pass a date-sorted array) |

---
**`Finoria-app/Extensions/ViewModifiers.swift`**

**Purpose:** Shared view modifiers and formatting helpers.

**Type:** `struct AdaptiveGroupedBackground: ViewModifier`, `struct AccountPickerToolbarModifier: ViewModifier`, View/Date/Double extensions, private cached `dayHeaderFormatter`.

**Dependencies:** SwiftUI, UIKit (UIColor trait resolution), AccountPickerView.

**Key members:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| .adaptiveGroupedBackground() | — | View | Black in dark mode, systemGroupedBackground in light, ignoring safe area |
| .accountPickerToolbar(isPresented:) | Binding\<Bool\> | View | Adds the trailing person-icon toolbar button + AccountPickerView sheet (picker reads the manager from the environment) |
| .if(_:transform:) | condition, closure | View | Conditional modifier helper (used by AllTransactionsView's embedded mode) — note: changes view identity when toggled |
| dayHeaderFormatter | private let DateFormatter | Cached fr_FR "EEEE d MMMM yyyy" (was per-call; hot path in list section headers) |
| Date.dayHeaderFormatted() | — | String | "Aujourd'hui" / "Hier" / "Lundi 5 février 2026" |
| Double.formattedCurrency | — | String | `formatted(.currency(code: "EUR"))` — underused; most views still use `"%.2f €"` literals |

---
**`Finoria-app/Extensions/ColorHex.swift`**

**Purpose:** Color ↔ hex-string conversion for custom category colors.

**Type:** `extension Color`.

**Dependencies:** SwiftUI, UIKit (UIColor component extraction).

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init(finoriaHex:) | hex: String | Color | Parses "#RRGGBB" (with/without #); invalid input → `.gray` |
| finoriaHex | — | String | "#RRGGBB" via UIColor getRed; failure → "#8E8E93" |

---
**`Finoria-app/Extensions/DateFormatting.swift`**

**Purpose:** French month-name helper for calendar navigation titles.

**Type:** `extension Date`.

**Dependencies:** Foundation.

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| monthName | static, month: Int | String | "Mars" for 3 — fr_FR, capitalized; empty string if components invalid. Creates a DateFormatter per call (cheap: called per visible row, not per frame) |

---

## Views/ (root)

---
**`Finoria-app/Views/ContentView.swift`**

**Purpose:** Root TabView wiring the four feature tabs plus the "+" pseudo-tab, app-level lifecycle hooks, onboarding, and the CloudKit status alert.

**Type:** `struct ContentView: View`

**Dependencies:** AccountsManager (env), @Query Account, HomeTabView, AnalysesTabView, CalendrierMainView, FutureTabView, AddTransactionView, WelcomeView, CloudKitService, AppStorageKeys.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| accountsManager | @Environment(AccountsManager.self) | Data manager |
| accounts | @Query(sort: \Account.name) | For first-account auto-selection |
| showingAddTransactionSheet / tabSelection | @State Bool / @State TabItem | Sheet + tab state; TabItem = home/analyses/calendrier/futur/add |
| scenePhase | @Environment | Foreground detection |
| hasSeenWelcome | @AppStorage(AppStorageKeys.hasSeenWelcome) | Onboarding flag |
| hasSeenICloudWarning | @AppStorage(AppStorageKeys.hasSeenICloudWarning) | Suppresses the iCloud alert once the user taps "Ne plus afficher" |
| showWelcomeSheet / showCloudKitAlert / cloudKitAlertTitle / cloudKitAlertMessage | @State | Onboarding + diagnostics UI state |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| checkCloudKit (private) | — | — | Returns early if `hasSeenICloudWarning`; otherwise `Task` → `CloudKitService.checkAccountStatus()`; shows the alert if iCloud is not available |

**SwiftUI body:** A `TabView` with Accueil / Analyses / Calendrier / Futur tabs and a fifth `Tab(role: .search)` rendering `Color.clear` — selecting it opens the add-transaction sheet and `onChange` snaps the selection back (the "+" is a button disguised as a tab). `onAppear`: auto-select first account, run the recurrence engine, CloudKit check, show welcome sheet once. `onChange(scenePhase == .active)`: `refreshFromStore()` + recurrence reprocessing. Hosts the welcome sheet (sets `hasSeenWelcome` on dismiss) and the iCloud diagnostics alert — its two buttons are "OK" (re-shows next launch while sync is broken) and "Ne plus afficher" (sets `hasSeenICloudWarning`, never shown again).

**Notes:** The `Tab(value:role:)` builder API requires iOS 18 — this file sets the app's true minimum OS.

---
**`Finoria-app/Views/WelcomeView.swift`**

**Purpose:** First-launch "What's New"-style onboarding sheet.

**Type:** `struct WelcomeView: View` + private `Feature` model + private `FeatureRow` view.

**Dependencies:** SwiftUI only.

**SwiftUI body:** Scrollable header ("Bienvenue dans **Finoria**") + 8 feature rows (multi-accounts, quick transactions, recurrences, analyses, calendar, future projections, iCloud sync, custom categories) + prominent "Continuer" button that dismisses. `interactiveDismissDisabled()` forces the button path (caller marks `hasSeenWelcome` on dismiss).

---
**`Finoria-app/Views/NoAccountView.swift`**

**Purpose:** Empty state shown by every tab when no account is selected.

**Type:** `struct NoAccountView: View`

**Dependencies:** AccountPickerView.

**SwiftUI body:** "Aucun compte sélectionné" + "Ajouter un compte" button opening the AccountPickerView sheet. Needs no manager reference itself.

---
**`Finoria-app/Views/DatabaseErrorView.swift`**

**Purpose:** Full-screen graceful failure UI when the SwiftData container cannot be created (both CloudKit and fallback configurations failed).

**Type:** `struct DatabaseErrorView: View`

**Dependencies:** SwiftUI only. Shown by FinoriaApp when `initErrorMessage != nil`.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| errorMessage | let String | The underlying error description |

**SwiftUI body:** Warning icon, title, the message, and a card of recovery suggestions (relaunch, reboot, reinstall).

---
**`Finoria-app/Views/DocumentPicker.swift`**

**Purpose:** SwiftUI wrapper around `UIDocumentPickerViewController` for picking a CSV file to import.

**Type:** `struct DocumentPicker: UIViewControllerRepresentable` + `class Coordinator: NSObject, UIDocumentPickerDelegate`.

**Dependencies:** SwiftUI, UIKit, UniformTypeIdentifiers.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| onPick | (URL) -> Void | Called with the first selected document URL |

**Notes:** Accepts `.commaSeparatedText` and `.plainText`; single selection.

---

## Views/Account/

---
**`Finoria-app/Views/Account/AccountCardView.swift`**

**Purpose:** Visual card for one account (used in the picker and the add/edit preview).

**Type:** `struct AccountCardView: View`

**Dependencies:** Account, compactAmount (StylableEnum.swift).

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| account / solde / futur | Account / Double / Double | Display data; `futur` = balance + potentials, shown as "→ X €" only when it differs |

**SwiftUI body:** Style icon tile, name + uppercased detail, compact balance (red when negative) with optional future projection line.

---
**`Finoria-app/Views/Account/AccountPickerView.swift`**

**Purpose:** Account list sheet — select, create, edit, reset, or delete accounts.

**Type:** `struct AccountPickerView: View`

**Dependencies:** AccountsManager (env), @Query Account, AccountCardView, AddAccountSheet.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| dismiss | @Environment(\.dismiss) | Sheet dismissal |
| accountsManager | @Environment(AccountsManager.self) | Writes + totals |
| accounts | @Query(sort: \Account.name) | Live account list straight from SwiftData |
| showingAddAccount / accountToEdit / accountToReset / showingResetConfirmation | @State | Sheet/alert state |

**SwiftUI body:** Plain list of `AccountCardView`s (balance + future via manager totals); tap selects (`selectedAccountId = id`) and dismisses; context menu offers Modifier / Réinitialiser (destructive, confirmed — deletes all transactions but keeps shortcuts/recurrences/categories) / Supprimer; trailing swipe deletes. Footer "Ajouter un compte" button opens AddAccountSheet (auto-selects the new account and dismisses the picker via callback).

---
**`Finoria-app/Views/Account/AddAccountSheet.swift`**

**Purpose:** Create/edit account form.

**Type:** `struct AddAccountSheet: View`

**Dependencies:** AccountsManager (env), AccountCategoryPicker, AccountCardView, Account/AccountStyle.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| onAccountCreated | (() -> Void)? | Called after creation (picker uses it to dismiss) |
| accountToEdit | Account? | nil = create mode |
| name / detail / style / hasManuallySelectedStyle | @State | Form state; maxName 15, maxDetail 20 |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| init | accountToEdit = nil, onAccountCreated = nil | — | Manager comes from the environment |
| saveAccount (private) | — | — | Trims/validates name; create → `addAccount` + select + callback; edit → `updateAccount` |

**SwiftUI body:** Form: name (auto-guesses the style while typing until manually overridden) + detail with live character counters, `AccountCategoryPicker` (5 columns), live `AccountCardView` preview, destructive delete section in edit mode. Cancel / Créer-OK toolbar.

---

## Views/Components/

---
**`Finoria-app/Views/Components/CurrencyTextField.swift`**

**Purpose:** Reusable € amount field.

**Type:** `struct CurrencyTextField: View`

**Dependencies:** SwiftUI only.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| placeholder | String (default "Montant") | Field label |
| amount | @Binding Double? | nil when empty |

**SwiftUI body:** `TextField` with `.number.precision(.fractionLength(0...2))` format, decimal-pad keyboard, trailing gray "€" overlay.

---
**`Finoria-app/Views/Components/AccountCategoryPicker.swift`**

**Purpose:** Generic grid style picker for any `StylableEnum` (extracted from StylableEnum.swift).

**Type:** `struct AccountCategoryPicker<Style: StylableEnum>: View`

**Dependencies:** SwiftUI, StylableEnum.

| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| AccountCategoryPicker | selectedStyle: Binding, columns = 4, collapsedRows?, onManualSelection? | View | Grid of style tiles; collapsed mode shows N rows with a "Voir tout"/"Voir moins" expander and always keeps the selection visible |

---
**`Finoria-app/Views/Components/TransactionCategoryPicker.swift`**

**Purpose:** Paginated transaction-category picker with custom categories and an add tile (extracted from StylableEnum.swift, with its private sub-views).

**Type:** `struct TransactionCategoryPicker: View` + private `CategorySheetContext`, `CategoryPickerItem`, `TransactionCategoryTileView`, `PageControlIndicator`.

**Dependencies:** SwiftUI, UIKit (haptics), AccountsManager (env + normalizeCategoryName), TransactionCategory, CustomTransactionCategory, AddCustomTransactionCategorySheet.

| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| TransactionCategoryPicker | selectedStyle: Binding\<TransactionCategory\>, selectedCustomCategoryId: Binding\<UUID?\>, onManualSelection? | View | Paginated grid (5×2 per page, swipeable TabView + page dots): built-ins + custom categories + "add" tile. Tap selects (custom → `.other` + id); long-press: info popover (built-in) or edit/delete (custom); add/edit opens AddCustomTransactionCategorySheet with name validation (non-empty, unique vs built-ins and customs, normalized via `AccountsManager.normalizeCategoryName`); auto-scrolls to the selected item's page |

**Notes:** Reads `AccountsManager` from the environment — only usable inside the injected hierarchy. Uses `LongPressGesture` + anchored `popover` (not `contextMenu`, which misbehaves inside Form/List).

---
**`Finoria-app/Views/Components/StyleIconView.swift`**

**Purpose:** Colored circle + SF Symbol for any `StylableEnum` (extracted from StylableEnum.swift).

**Type:** `struct StyleIconView<Style: StylableEnum>: View`

**Dependencies:** SwiftUI, StylableEnum.

| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| StyleIconView | style, size = 40 | View | Colored circle + SF Symbol sized to `size` |

---
**`Finoria-app/Views/Components/DayGroupedTransactionSections.swift`**

**Purpose:** Reusable day-sectioned transaction rows — the shared rendering extracted from AllTransactionsView and CategoryTransactionsView.

**Type:** `struct DayGroupedTransactionSections: View`

**Dependencies:** SwiftUI, AccountsManager (env, delete), Transaction, TransactionRow, `groupedByDay()`, `dayHeaderFormatted()`.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| transactions | [Transaction] | Already filtered/sorted list to display |
| onEdit | (Transaction) -> Void | Tap callback (caller presents the edit sheet) |

**SwiftUI body:** `ForEach(transactions.groupedByDay())` → one `Section` per day (`dayHeaderFormatted()` header) of `TransactionRow`s with tap-to-edit and trailing swipe-to-delete (`accountsManager.deleteTransaction`, animated). Produces `Section`s — place it directly inside a `List`.

---

## Views/Transactions/

---
**`Finoria-app/Views/Transactions/AddTransactionView.swift`**

**Purpose:** Create/edit transaction form (also used for future/potential transactions).

**Type:** `struct AddTransactionView: View`

**Dependencies:** AccountsManager (env), CurrencyTextField, TransactionCategoryPicker, TransactionCategory, Transaction.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| transactionToEdit | Transaction? | nil = create |
| initialIsPotentiel / initialTransactionType | Bool / TransactionType | Presets used by Futur tab and Analyses empty states |
| montant, transactionComment, transactionType, transactionDate, isPotentiel, selectedCategory, selectedCustomCategoryId, hasManuallySelectedCategory | @State | Form state; comment max 30, amount max 999 999 999,99 |
| showingErrorAlert / errorMessage | @State | Validation feedback |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| saveTransaction (private) | — | — | Validates (amount > 0, non-empty comment, max amount); sign from type; potential → date nil; resolves custom category; create via `addTransaction` or edit via `updateTransaction`; dismisses |

**SwiftUI body:** `NavigationStack` form: type segmented picker, amount + comment (auto-categorizes from keywords until manual pick), `TransactionCategoryPicker`, "Transaction future" toggle (hides the graphical date picker when on), destructive delete in edit mode. `onAppear` pre-fills from `transactionToEdit` or the `initial*` presets.

---
**`Finoria-app/Views/Transactions/TransactionRow.swift`**

**Purpose:** Canonical single-transaction list row used by every transaction list.

**Type:** `struct TransactionRow: View`

**Dependencies:** Transaction (display helpers).

**SwiftUI body:** Category icon circle (custom-aware color/symbol), comment + abbreviated date (when present), trailing signed amount in green/red.

---
**`Finoria-app/Views/Transactions/AddCustomTransactionCategorySheet.swift`**

**Purpose:** Create/edit a custom category: name, color, and symbol from a curated grid.

**Type:** `struct AddCustomTransactionCategorySheet: View`

**Dependencies:** ColorHex extension. Presented by TransactionCategoryPicker.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| title, initialName, initialSymbol, initialColorHex, maxNameLength (15) | let | Configuration from the caller |
| onValidateName | (String) -> String? | Returns an error message or nil — uniqueness checked by the caller |
| onSave | (name, symbol, colorHex) -> Void | Persistence delegated to the caller |
| name / selectedSymbol / selectedColor / showingErrorAlert / errorMessage | @State | Form state |
| symbolOptions | [String] | Curated list of 72 SF Symbols |

**SwiftUI body:** Form: name with counter, `ColorPicker` (no opacity), live symbol preview + 6-column symbol grid with selection ring. Valider runs trim → `onValidateName` → `onSave` → dismiss; errors alert.

---

## Views/Recurring/

---
**`Finoria-app/Views/Recurring/AddRecurringTransactionView.swift`**

**Purpose:** Create/edit a recurring transaction template.

**Type:** `struct AddRecurringTransactionView: View`

**Dependencies:** AccountsManager (env), CurrencyTextField, TransactionCategoryPicker, RecurrenceFrequency.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| recurringToEdit | RecurringTransaction? | nil = create |
| amount, comment (max 20), type, selectedCategory, selectedCustomCategoryId, frequency, startDate, hasManuallySelectedCategory | @State | Form state |
| showError / errorMessage | @State | Validation feedback |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| saveRecurring (private) | — | — | Validates amount/comment; create → `addRecurringTransaction` (immediately processes occurrences); edit → `updateRecurringTransaction` (strips pending potentials, resets watermark, reprocesses); dismisses |

**SwiftUI body:** Form: amount + auto-categorizing comment, type segmented picker, frequency picker + "À partir du" compact date picker, `TransactionCategoryPicker`, destructive delete in edit mode.

---
**`Finoria-app/Views/Recurring/RecurringTransactionsGridView.swift`**

**Purpose:** Home-screen 2-column grid of recurrence cards with full lifecycle actions.

**Type:** `struct RecurringTransactionsGridView: View` + private `RecurringHeader`, `RecurringCard`.

**Dependencies:** RecurringTransaction, compactAmount, UIKit (haptics). Callback-driven (no manager).

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| recurringTransactions | [RecurringTransaction] | Data from HomeView |
| onEdit / onDelete / onPause / onResume / onAddTap | closures | All actions delegated to HomeView |

**SwiftUI body:** "Récurrences" header with Ajouter capsule; cards show icon, comment, signed compact amount, frequency short label. Paused cards are desaturated with a tappable pause badge to resume. Tap (with haptic) edits; context menu offers edit / pause-resume / delete.

---

## Views/Widget/ (shortcuts & toasts)

---
**`Finoria-app/Views/Widget/AddWidgetShortcutView.swift`**

**Purpose:** Create/edit a one-tap shortcut template.

**Type:** `struct AddWidgetShortcutView: View`

**Dependencies:** AccountsManager (env), CurrencyTextField, TransactionCategoryPicker.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| shortcutToEdit | WidgetShortcut? | nil = create |
| amount, comment (max 15), type, selectedCategory, selectedCustomCategoryId, hasManuallySelectedCategory, showError, errorMessage | @State | Form state |

**Methods:** `saveShortcut()` — validates then `addWidgetShortcut` / `updateWidgetShortcut`, dismisses.

**SwiftUI body:** Same form pattern as the other editors (amount, auto-categorizing comment, type segmented, category picker, delete in edit mode).

---
**`Finoria-app/Views/Widget/Toast/ToastData.swift`**

**Purpose:** Toast payload model.

**Type:** `struct ToastData: Identifiable` — `id: UUID`, `message: String`. No methods.

---
**`Finoria-app/Views/Widget/Toast/ToastView.swift`**

**Purpose:** Visual capsule for one toast message.

**Type:** `struct ToastView: View` — `message`, `darkenOverlay: Double`, `scale: CGFloat`.

**SwiftUI body:** Rounded-rectangle capsule with the message, a darkening overlay (for stacked depth), and a scale effect.

---
**`Finoria-app/Views/Widget/Toast/ToastCard.swift`**

**Purpose:** Interactive wrapper adding depth styling and swipe-down-to-dismiss to a toast.

**Type:** `struct ToastCard: View` — `toast: ToastData`, `depth: Int` (0 = front), `onDismiss: (UUID) -> Void`, `@State dragOffset`.

**SwiftUI body:** `ToastView` scaled/shadowed/darkened by depth, draggable downward; releases past 50 pt or with downward fling velocity dismiss, otherwise springs back.

---

## Views/TabView/ — Home

---
**`Finoria-app/Views/TabView/HomeTabView.swift`**

**Purpose:** Home tab shell: navigation chrome plus CSV export (share) and import.

**Type:** `struct HomeTabView: View`.

**Dependencies:** AccountsManager (env), HomeView, NoAccountView, DocumentPicker, CSVService, accountPickerToolbar.

**Key members:**
| Name | Type / Params | Description |
|------|---------------|-------------|
| csvURL | @State URL? | Pre-generated export file; nil when the account has no exportable transaction |
| csvTaskID | computed String | `selectedAccount.persistentModelID` + `dataVersion` — the `.task(id:)` key; changes on account switch or any mutation |
| prepareCSV (private) | async | Snapshots via `accountsManager.csvExportSnapshot()` on the main actor, then a `Task.detached` runs `CSVService.generateCSV` off-main and stores the result in `csvURL` (keeps the previous file until the new one is ready) |
| importCSV (private) | from URL | `accountsManager.importCSV`; success/error alert with imported count |

**SwiftUI body:** `NavigationStack` → `HomeView` (or `NoAccountView`). Leading toolbar: when `csvURL` is ready, a `ShareLink(item: url)` opens the share sheet **instantly** (file already generated); when nil, a dimmed button raises a "no transaction" alert; plus an import button opening `DocumentPicker`. `.task(id: csvTaskID)` (re)generates the CSV whenever the account or data changes. Hosts import success/error and no-transaction alerts. Trailing account-picker toolbar via modifier.

**Notes:** The CSV is generated ahead of time by `.task(id:)` (off the main actor) and cached in `csvURL`, so `ShareLink` opens with no delay; `ShareLink(item:)` gives correct iPad popover anchoring.

---
**`Finoria-app/Views/TabView/HomeView.swift`**

**Purpose:** Home dashboard: balance header, quick cards, shortcuts grid, recurrences grid, toast stack.

**Type:** `struct HomeView: View`

**Dependencies:** AccountsManager (env), HomeComponents (BalanceHeaderContent, QuickCardContent, ToastStackView), ShortcutsGridView, RecurringTransactionsGridView, AllTransactionsView, TransactionsListView, PotentialTransactionsView, AddWidgetShortcutView, AddRecurringTransactionView, ToastData.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| sheet/alert states | @State | showingAddWidgetSheet, showingAddRecurringSheet, shortcutToEdit/Delete, recurringToEdit/Delete, two delete confirmations |
| toasts | @State [ToastData] | Active toast stack |
| totalCurrent / totalPotential / currentMonthSolde / currentMonth / currentYear | computed | Manager totals + calendar components |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| executeShortcut (private) | shortcut | — | Builds a validated Transaction (sign by type, date now) → `addTransaction` → toast "Transaction ajoutée 💸" |
| addToast / removeToast (private) | message / id | — | Spring-animated stack; auto-dismiss after 2.5 s |

**SwiftUI body:** ScrollView: balance header (NavigationLink → AllTransactionsView) with monthly % change; two quick cards (Solde du mois → TransactionsListView(current month); À venir → PotentialTransactionsView); ShortcutsGridView (tap executes, context menu edits/deletes with confirmation); RecurringTransactionsGridView (full lifecycle callbacks into the manager). Toast stack overlays at the bottom. Sheets for add/edit shortcut and recurrence; delete-confirmation alerts.

---
**`Finoria-app/Views/TabView/Home/HomeComponents.swift`**

**Purpose:** Presentational subcomponents of the home dashboard.

**Type:** `struct BalanceHeaderContent: View`, `struct PercentageChangeIndicator: View`, `struct QuickCardContent: View`, `struct ToastStackView: View`.

**Dependencies:** SwiftUI, ToastData/ToastCard.

**Key members:**
| Name | Inputs | Description |
|------|--------|-------------|
| BalanceHeaderContent | accountName?, totalCurrent?, percentageChange? | Account name, "SOLDE TOTAL" label, large balance (red when negative), % indicator |
| PercentageChangeIndicator | percentage? | Arrow + "+x,x% ce mois-ci" colored green/red/neutral; nil renders "+0.0%" |
| QuickCardContent | icon, iconColor, title, value? | Rounded card with icon circle, title, amount |
| ToastStackView | toasts, onDismiss | Overlapping `ToastCard`s (−30 spacing) with depth styling and move/opacity transitions |

---
**`Finoria-app/Views/TabView/Home/ShortcutsGridView.swift`**

**Purpose:** Home-screen 2-column grid of one-tap shortcut cards.

**Type:** `struct ShortcutsGridView: View` + private `ShortcutsHeader`, `ShortcutCard`.

**Dependencies:** WidgetShortcut, compactAmount, UIKit (haptics). Callback-driven.

**Properties:** `shortcuts: [WidgetShortcut]`, `onShortcutTap/Edit/Delete`, `onAddTap` closures.

**SwiftUI body:** "Raccourcis" header with Ajouter capsule; cards show category icon, comment, signed compact amount; tap fires haptic + executes; context menu edits/deletes.

**Notes:** Near-duplicate of RecurringTransactionsGridView's card/header (audit: extraction candidate).

---

## Views/TabView/ — Futur

---
**`Finoria-app/Views/TabView/FutureTabView.swift`**

**Purpose:** Futur tab shell.

**Type:** `struct FutureTabView: View`

**Dependencies:** AccountsManager (env), PotentialTransactionsView, NoAccountView, accountPickerToolbar.

**SwiftUI body:** `NavigationStack` titled "Futur" → `PotentialTransactionsView` or `NoAccountView`, with the account-picker toolbar.

---
**`Finoria-app/Views/TabView/PotentialTransactionsView.swift`**

**Purpose:** List of future/potential transactions, split between recurrence-generated and manual, with validate/delete swipes.

**Type:** `struct PotentialTransactionsView: View`

**Dependencies:** AccountsManager (env), TransactionRow, AddTransactionView.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| recurringTransactions | computed [Transaction] | Potentials with a `sourceRecurringTransaction`, newest planned date first |
| normalTransactions | computed [Transaction] | Manual potentials, reverse insertion order |
| sheet/alert states | @State | Add sheet, edit item, delete/validate confirmations for recurrence-generated rows |

**SwiftUI body:** Two list sections ("Transactions récurrentes" / "Futures"); tappable empty state opens the add sheet preset to potential. Each row: tap to edit; trailing swipe deletes (with a warning alert when recurrence-generated — it will be regenerated); leading swipe validates (alert for recurrence-generated: it joins the current balance).

---

## Views/TabView/Analyses/

---
**`Finoria-app/Views/TabView/Analyses/AnalysesModels.swift`**

**Purpose:** Value types shared by the Analyses feature.

**Type:** `struct CategoryData: Identifiable` (UUID id, category, total, count) + `enum AnalysisType: String, CaseIterable` ("Dépenses"/"Revenus") + `struct CategoryDetailRoute: Hashable` (category, month, year — navigation value).

**Dependencies:** TransactionCategory.

---
**`Finoria-app/Views/TabView/Analyses/AnalysesTabView.swift`**

**Purpose:** Analyses tab shell with the category drill-down navigation destination.

**Type:** `struct AnalysesTabView: View`

**Dependencies:** AccountsManager (env), AnalysesView, CategoryTransactionsView, NoAccountView, accountPickerToolbar, CategoryDetailRoute.

**SwiftUI body:** `NavigationStack` titled "Analyses" → `AnalysesView` (or `NoAccountView`), `navigationDestination(for: CategoryDetailRoute.self)` → `CategoryTransactionsView(category:month:year:)`, account-picker toolbar.

---
**`Finoria-app/Views/TabView/Analyses/AnalysesView.swift`**

**Purpose:** Category breakdown screen: expenses/income toggle, month navigation, donut chart, ranked category list.

**Type:** `struct AnalysesView: View`

**Dependencies:** AccountsManager (env), AnalysesPieChart, CategoryBreakdownRow, AddTransactionView, AnalysesModels, DateFormatting.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| analysisType / selectedSlice / selectedMonth / selectedYear / showingAddTransactionSheet | @State | UI state |
| currentMonth / currentYear | let | Captured in `init()` to cap forward navigation at the present |
| filteredTransactions / categoryData / totalAmount / chartDisplayData / displayTotal | computed | Validated transactions of the selected month filtered by sign; grouped per built-in category (total + count), sorted desc; `chartDisplayData` inflates slices to ≥1 % of the total so tiny ones stay tappable |

**Methods:** `goToPreviousMonth()` / `goToNextMonth()` (clamped to today via `canGoNext`).

**SwiftUI body:** Inset-grouped list: Dépenses/Revenus segmented picker + ‹ month year › navigator; donut chart section; one `CategoryBreakdownRow` per category as a `NavigationLink(value: CategoryDetailRoute)`, highlighted when its slice is selected. Tappable empty state opens AddTransactionView preset to the current type. Changing type clears the slice selection.

**Notes:** Custom-category spending appears under "Autre" (custom categories store `.other` underneath).

---
**`Finoria-app/Views/TabView/Analyses/AnalysesPieChart.swift`**

**Purpose:** Interactive Swift Charts donut with center summary and manual slice hit-testing.

**Type:** `struct AnalysesPieChart: View`

**Dependencies:** Charts, AnalysesModels, StyleIconView.

**Properties:**
| Name | Type | Description |
|------|------|-------------|
| chartData / categoryData | [CategoryData] | Display (1 %-inflated) vs real values |
| total / displayTotal | Double | Real total (center text) vs inflated total (angle math) |
| analysisType | AnalysisType | "dépensés"/"gagnés" center caption |
| selectedSlice | @Binding TransactionCategory? | Selection shared with the list |

**Methods / Computed vars:**
| Name | Parameters | Returns | Description |
|------|-----------|---------|-------------|
| handleChartTap (private) | location, size | — | Converts tap point to polar coordinates; inside the ring → angle fraction × displayTotal → category (toggle select); outside/center → deselect |
| findCategory (private) | cumulated value | TransactionCategory? | Walks cumulative slice totals |

**SwiftUI body:** `Chart` of `SectorMark`s (inner radius 0.6, dimming unselected slices to 0.4 opacity when one is selected); `chartBackground` shows either the selected category (icon + amount + label) or the real total; `chartOverlay` GeometryReader captures taps. Height 240.

---
**`Finoria-app/Views/TabView/Analyses/CategoryBreakdownRow.swift`**

**Purpose:** One ranked row of the category list: icon, name, count, amount, share %.

**Type:** `struct CategoryBreakdownRow: View` — `item: CategoryData`, `totalAmount: Double`, `isSelected: Bool`; computed `percentage` (guarded ÷ 0).

**SwiftUI body:** `StyleIconView` + label + "N transaction(s)" on the left; EUR amount + "x,x %" on the right.

---
**`Finoria-app/Views/TabView/Analyses/CategoryTransactionsView.swift`**

**Purpose:** Drill-down: a category's validated transactions for the selected month, grouped by day.

**Type:** `struct CategoryTransactionsView: View`

**Dependencies:** AccountsManager (env), AddTransactionView, CategoryIconView, DayGroupedTransactionSections.

**Properties:** `category`, `customCategoryId` (nil for built-ins), `month`, `year` (lets); `@State transactionToEdit`; computed `customCategory` / `displayLabel` / `displayIcon` / `displayColor` and `categoryTransactions` (validated, month-filtered, category-filtered via `belongs(_:)`, date desc).

**SwiftUI body:** `DayGroupedTransactionSections(transactions: categoryTransactions)` inside a `List`; `CategoryIconView` empty state; navigation title = category label.

**Notes:** Day-grouping/rendering now factored into the shared `DayGroupedTransactionSections` component (was duplicated with AllTransactionsView).

---

## Views/TabView/Calendrier/

---
**`Finoria-app/Views/TabView/Calendrier/CalendrierRoute.swift`**

**Purpose:** Navigation values for calendar drill-down.

**Type:** `enum CalendrierRoute: Hashable` — `.months(year:)`, `.transactions(month:year:)`. No methods.

---
**`Finoria-app/Views/TabView/Calendrier/CalendrierMainView.swift`**

**Purpose:** Calendrier tab shell.

**Type:** `struct CalendrierMainView: View`

**Dependencies:** AccountsManager (env), CalendrierTabView, NoAccountView, accountPickerToolbar.

**SwiftUI body:** `NavigationStack` → `CalendrierTabView` or `NoAccountView` ("Calendrier"), with the account-picker toolbar.

---
**`Finoria-app/Views/TabView/Calendrier/CalendrierTabView.swift`**

**Purpose:** Calendar content with Jour / Mois / Année segmented modes and the route destinations.

**Type:** `enum CalendrierViewMode: String, CaseIterable` + `struct CalendrierTabView: View` + private `CalendrierYearsContentView`, `CalendrierMonthsContentView`.

**Dependencies:** AccountsManager (env), AllTransactionsView, MonthsView, TransactionsListView, AddTransactionView, CalendrierRoute, DateFormatting, adaptiveGroupedBackground.

**Properties:** `@State selectedMode` (.jour default), `@State showingAddTransactionSheet`; `CalendrierMonthsContentView.monthsWithData` computes (year, month, total ≠ 0) tuples with composed string ids, most recent first.

**SwiftUI body:** Segmented picker on top; tappable "Aucune transaction" empty state; mode content: Jour → `AllTransactionsView(embedded: true)`, Mois → flat list of every non-zero month across years (NavigationLink → `.transactions`), Année → list of years with totals (NavigationLink → `.months`); colors green/red by sign. `navigationDestination(for: CalendrierRoute.self)` maps to MonthsView / TransactionsListView.

---
**`Finoria-app/Views/TabView/Calendrier/MonthsView.swift`**

**Purpose:** The 12 months of one year with non-zero totals.

**Type:** `struct MonthsView: View`

**Dependencies:** AccountsManager (env), CalendrierTabView (fallback), AccountPickerView, CalendrierRoute, DateFormatting.

**Properties:** `year: Int`, `@State showingAccountPicker`.

**SwiftUI body:** December→January list of months with non-zero totals (NavigationLink → `.transactions(month:year:)`), green/red totals, person toolbar button + picker sheet. If the account has no transactions at all, renders `CalendrierTabView` instead.

---
**`Finoria-app/Views/TabView/Calendrier/TransactionsListView.swift`**

**Purpose:** Flat list of validated transactions, optionally filtered by month/year (used by calendar drill-down and the home "Solde du mois" card).

**Type:** `struct TransactionsListView: View`

**Dependencies:** AccountsManager (env), TransactionRow, AddTransactionView, AccountPickerView, DateFormatting.

**Properties:** `month: Int?`, `year: Int?`; `@State` picker/edit/add states; computed `sortedTransactions` (validated, period-filtered, date desc) and `titleText` ("Mars 2026" / "2026" / "Transactions").

**SwiftUI body:** List of `TransactionRow`s — tap edits, trailing swipe deletes; tappable empty state opens the add sheet; person toolbar + picker sheet.

---
**`Finoria-app/Views/TabView/Calendrier/AllTransactionsView.swift`**

**Purpose:** Every validated transaction grouped by day — standalone screen or embedded in the calendar's Jour mode.

**Type:** `struct AllTransactionsView: View`

**Dependencies:** AccountsManager (env), DayGroupedTransactionSections, AddTransactionView, AccountPickerView, `.if` modifier.

**Properties:** `embedded: Bool = false` (hides title/toolbar and scroll background when true); `@State` picker/edit/add states; computed `allTransactions` (validated, date desc).

**SwiftUI body:** `DayGroupedTransactionSections(transactions: allTransactions)` inside a `List` (day headers "Aujourd'hui"/"Hier"/full date, edit tap, animated delete swipe); tappable empty state; when not embedded: "Toutes les transactions" title + person toolbar.

---

## Test targets

---
**`Finoria-appTests/Finoria_appTests.swift`** — **Purpose:** Unit test target. **Type:** `final class Finoria_appTests: XCTestCase`. **Notes:** Untouched Xcode template (empty `testExample`, `testPerformanceExample`) — no real coverage.

---
**`Finoria-appUITests/Finoria_appUITests.swift`** — **Purpose:** UI test target. **Type:** `final class Finoria_appUITests: XCTestCase`. **Notes:** Untouched template (app-launch `testExample`, `testLaunchPerformance`).

---
**`Finoria-appUITests/Finoria_appUITestsLaunchTests.swift`** — **Purpose:** Launch-screenshot test. **Type:** `final class Finoria_appUITestsLaunchTests: XCTestCase`. **Notes:** Untouched template (`testLaunch` captures a launch screenshot attachment).

---

# Cross-Cutting Concerns

**Data Flow Diagram (text):**

```
                       ┌────────────────────────────────────────────┐
                       │   SwiftData store (on-disk, CloudKit-backed)│
                       └────────────┬───────────────────┬───────────┘
              @Query (account lists)│                    │ fetch via selectedAccount
                                    ▼                    ▼
   ┌────────────┐  read helpers  ┌──────────────────────────────────┐
   │   Views    │ ─────────────▶ │  AccountsManager (@MainActor,    │
   │  (SwiftUI) │  write methods │  @Observable — single write path)│
   └────────────┘ ─────────────▶ └────────────┬─────────────────────┘
        ▲                                     │ delegates to
        │ dataVersion (observed token)        ▼
        │ invalidates after persist()  CalculationService / RecurrenceEngine / CSVService
        │                                     │
        └────────────── persist() = ModelContext.save() + dataVersion += 1
                                              │
                                              ▼
                          CloudKit (automatic via SwiftData .automatic;
                          silent pushes → merge → refreshFromStore() on foreground)
```

**Concurrency Model:**
- `AccountsManager` is `@MainActor` (and therefore implicitly `Sendable`); every model read/write, every view interaction, and all five `@Model` classes live on the main actor (`ModelContainer.mainContext` requirement).
- `async/await` appears in: `CloudKitService.checkAccountStatus()`/`verifyContainerAccess()` (CKContainer async APIs, called from a `Task` in ContentView); and HomeTabView's CSV export — `prepareCSV()` runs inside a `.task(id:)`, takes the main-actor snapshot `csvExportSnapshot()`, then `await`s a `Task.detached` that builds the file off-main.
- `CSVService.ExportRow` is the only purpose-built `Sendable` value type; it exists so transaction data can legally cross from the main actor to the export closure.
- The project compiles in **Swift 5 language mode** — these annotations are design contracts, not yet compiler-enforced. Enable `SWIFT_STRICT_CONCURRENCY = complete` before migrating to Swift 6 mode.

**State Management Summary:**

| State | Where it lives | Type | Scope |
|-------|---------------|------|-------|
| All domain data (accounts, transactions, recurrences, shortcuts, custom categories) | SwiftData store | 5 `@Model` classes | Persistent, CloudKit-synced |
| Selected account id | AccountsManager | `var selectedAccountId: UUID?` (observed; mirrored to UserDefaults) | App-wide; device-local preference |
| Selected account object | AccountsManager | `var selectedAccount: Account?` (computed fetch) | App-wide, derived |
| Data invalidation token | AccountsManager | `private(set) var dataVersion: Int` (observed) | App-wide — bumped by every persist/foreground refresh |
| Pre-generated CSV export file | HomeTabView | `@State var csvURL: URL?` | Ready-to-share export, regenerated by `.task(id:)` on account/data change |
| Last persistence error | AccountsManager | `var lastPersistenceError: String?` (observed) | App-wide; not yet surfaced by any view |
| Account lists | ContentView, AccountPickerView | `@Query(sort: \Account.name)` | Per-view, live |
| Onboarding seen | ContentView | `@AppStorage(AppStorageKeys.hasSeenWelcome)` | Persistent, device-local |
| iCloud warning dismissed | ContentView | `@AppStorage(AppStorageKeys.hasSeenICloudWarning)` | Persistent, device-local |
| Tab selection | ContentView | `@State TabItem` | Session |
| Toast stack | HomeView | `@State [ToastData]` | Session, view-local |
| Analyses selection (type, slice, month/year) | AnalysesView | `@State` | Session, view-local |
| Calendar mode (Jour/Mois/Année) | CalendrierTabView | `@State CalendrierViewMode` | Session, view-local |
| Form drafts & sheet/alert toggles | Each editor view | `@State` | Transient, view-local |

**Data Persistence & Schema Migration (zero data loss):**

Persistence is versioned end-to-end so the data structure can evolve across app updates without ever losing user data (on device or in iCloud).

- **Source of truth:** [`FinoriaSchema.swift`](Finoria-app/Models/FinoriaSchema.swift) — `FinoriaSchemaV1` (frozen snapshot of the shipped models), `FinoriaMigrationPlan` (versions + migration stages), and the `FinoriaCurrentSchema` alias.
- **Wiring:** `SwiftDataService` builds **all three** containers (production CloudKit, on-disk fallback, in-memory preview) from `Schema(versionedSchema: FinoriaCurrentSchema.self)` and passes `migrationPlan: FinoriaMigrationPlan.self`. The migration plan therefore runs identically in every mode.
- **Golden rule:** never modify a `FinoriaSchemaVx` already shipped. To change the structure: create `FinoriaSchemaV2`, add a `MigrationStage` (`.lightweight` for additive changes, `.custom` with `willMigrate`/`didMigrate` for renames/transforms), register both in `FinoriaMigrationPlan`, then point `FinoriaCurrentSchema` at V2.
- **CloudKit constraint:** schema changes must be additive (new properties with defaults, new models, optional relationships). Never delete/rename server-side fields; to "rename", add the new field, migrate the data, keep the old one.
- **Guardrails:** every `@Model` carries a one-line reminder pointing to `FinoriaSchema.swift`; the file header holds the full procedure + a copy-paste V2 template. Migrations must be tested against an old-version store before publishing.
