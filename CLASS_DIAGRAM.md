# Finoria — Diagramme de classes

Vue d'ensemble des classes de l'application (modèles, orchestrateur, services, vues).

> Rendu automatiquement par GitHub. Pour modifier, éditer les blocs `mermaid` ci-dessous.
> Une version PlantUML équivalente existe dans [CLASS_DIAGRAM.puml](CLASS_DIAGRAM.puml).

## 1. Modèle de données (SwiftData) & enums

```mermaid
classDiagram
    direction LR

    class Account {
        <<@Model>>
        +UUID id
        +String name
        +String detail
        +AccountStyle style
    }

    class Transaction {
        <<@Model>>
        +UUID id
        +Double amount
        +String comment
        +Bool potentiel
        +Date? date
        +TransactionCategory category
        +String? importedCategoryName
        +validate(at)
        +modify(...)
        +displayCategoryLabel String
        +displayCategoryIcon String
        +displayCategoryColor Color
    }

    class WidgetShortcut {
        <<@Model>>
        +UUID id
        +Double amount
        +String comment
        +TransactionType type
        +TransactionCategory category
        +CustomTransactionCategory? customCategory
        +displayCategoryIcon String
        +displayCategoryColor Color
    }

    class RecurringTransaction {
        <<@Model>>
        +UUID id
        +Double amount
        +String comment
        +TransactionType type
        +TransactionCategory category
        +CustomTransactionCategory? customCategory
        +RecurrenceFrequency frequency
        +Date startDate
        +Date? lastGeneratedDate
        +Bool isPaused
        +occurrences(from, to) Date[]
        +pendingTransactions() Tuple[]
    }

    class CustomTransactionCategory {
        <<@Model>>
        +UUID id
        +String name
        +String symbol
        +String colorHex
        +resolvedColor Color
    }

    class StylableEnum {
        <<protocol>>
        +String icon
        +Color color
        +String label
    }

    class AccountStyle {
        <<enumeration>>
        bank savings investment business travel
        grocery student family property entertainment
        +guessFrom(name) AccountStyle
    }

    class TransactionType {
        <<enumeration>>
        income
        expense
        +label String
    }

    class TransactionCategory {
        <<enumeration>>
        salary income freelance bonus
        rent utilities home
        subscription phone insurance
        food grocery coffee
        fuel transport car
        loan savings investment tax
        shopping party sport travel culture
        family health gift education pet
        expense other
        +guessFrom(comment, type) TransactionCategory
    }

    class RecurrenceFrequency {
        <<enumeration>>
        daily weekly monthly yearly
        +label String
        +shortLabel String
    }

    Account "1" *-- "0..*" Transaction : transactions, cascade
    Account "1" *-- "0..*" WidgetShortcut : widgetShortcuts, cascade
    Account "1" *-- "0..*" RecurringTransaction : recurringTransactions, cascade
    Account "1" *-- "0..*" CustomTransactionCategory : customTransactionCategories, cascade

    Transaction "0..*" --> "0..1" CustomTransactionCategory : customCategory, nullify
    WidgetShortcut "0..*" --> "0..1" CustomTransactionCategory : customCategory
    RecurringTransaction "0..*" --> "0..1" CustomTransactionCategory : customCategory
    Transaction "0..*" --> "0..1" RecurringTransaction : sourceRecurringTransaction, nullify

    StylableEnum <|.. AccountStyle
    StylableEnum <|.. TransactionCategory

    Account ..> AccountStyle
    Transaction ..> TransactionCategory
    WidgetShortcut ..> TransactionType
    WidgetShortcut ..> TransactionCategory
    RecurringTransaction ..> TransactionType
    RecurringTransaction ..> TransactionCategory
    RecurringTransaction ..> RecurrenceFrequency
```

## 2. Orchestration & services

```mermaid
classDiagram
    direction LR

    class AccountsManager {
        <<@Observable, @MainActor>>
        -ModelContext modelContext
        +UUID? selectedAccountId
        +Account? selectedAccount
        +String? lastPersistenceError
        +Int dataVersion
        +persist()
        +refreshFromStore()
        +transactions() Transaction[]
        +addTransaction(t)
        +validateTransaction(t)
        +processRecurringTransactions()
        +importCSV(url) Int
        +csvExportSnapshot() Snapshot
        CRUD comptes, transactions, raccourcis
        CRUD récurrences, catégories perso
        Calculs délégués: totaux, années, pourcentage
    }

    class SwiftDataService {
        <<enum namespace>>
        +makeContainer() ModelContainer
        +makeFallbackContainer() ModelContainer
        +makePreviewContainer() ModelContainer
    }

    class RecurrenceEngine {
        <<struct>>
        +processAll(accounts, context) Bool
        +removePotentialTransactions(for, context)
    }

    class CalculationService {
        <<struct>>
        +totalNonPotential(transactions) Double
        +totalPotential(transactions) Double
        +availableYears(transactions) Int[]
        +totalForYear(year, transactions) Double
        +totalForMonth(month, year, transactions) Double
        +monthlyChangePercentage(transactions) Double?
        +validatedTransactions(...) Transaction[]
    }

    class CSVService {
        <<struct>>
        +generateCSV(rows, accountName) URL?
        +importCSV(url) Transaction[]
    }

    class ExportRow {
        <<struct>>
        +Date? date
        +Double amount
        +String comment
        +String categoryLabel
    }

    class CloudKitService {
        <<enum namespace>>
        +checkAccountStatus() async CloudKitStatus
    }

    class CloudKitStatus {
        <<enumeration>>
        available
        noAccount
        restricted
        temporarilyUnavailable
        couldNotDetermine
        error
        +userMessage String
    }

    class NotificationManager {
        <<struct>>
        +NotificationManager shared
        +requestNotificationPermission()
        +scheduleWeeklyNotificationIfNeeded()
        +resetNotifications()
    }

    class AppStorageKeys {
        <<enum namespace>>
        +String lastSelectedAccountId
        +String hasSeenWelcome
        +String hasSeenICloudWarning
    }

    class FinoriaApp {
        <<@main, App>>
        -ModelContainer? modelContainer
        -AccountsManager? accountsManager
        +AppDelegate appDelegate
        +body Scene
    }

    class AppDelegate {
        <<UIApplicationDelegate>>
        +application(didFinishLaunching)
        +application(didRegisterForRemoteNotifications)
        +userNotificationCenter(willPresent)
    }

    FinoriaApp *-- "0..1" AccountsManager
    FinoriaApp *-- AppDelegate
    FinoriaApp ..> SwiftDataService
    FinoriaApp ..> CloudKitService
    FinoriaApp ..> NotificationManager

    AccountsManager ..> RecurrenceEngine
    AccountsManager ..> CalculationService
    AccountsManager ..> CSVService
    AccountsManager ..> SwiftDataService
    AccountsManager ..> AppStorageKeys

    CSVService *-- ExportRow
    CloudKitService ..> CloudKitStatus
```

## 3. Hiérarchie des vues (SwiftUI)

```mermaid
classDiagram
    direction TB

    class ContentView {
        <<View>>
        TabItem home analyses calendrier futur add
    }
    class HomeTabView {
        <<View>>
    }
    class AnalysesTabView {
        <<View>>
    }
    class CalendrierMainView {
        <<View>>
    }
    class FutureTabView {
        <<View>>
    }
    class AddTransactionView {
        <<View>>
    }
    class AddRecurringTransactionView {
        <<View>>
    }
    class AddWidgetShortcutView {
        <<View>>
    }
    class AccountPickerView {
        <<View>>
    }
    class AddAccountSheet {
        <<View>>
    }
    class AddCustomTransactionCategorySheet {
        <<View>>
    }
    class WelcomeView {
        <<View>>
    }
    class DatabaseErrorView {
        <<View>>
    }
    class ReusableComponents {
        <<View>>
        TransactionRow
        TransactionCategoryPicker
        AccountCategoryPicker
        StyleIconView
        CurrencyTextField
        DayGroupedTransactionSections
        ShortcutsGridView / RecurringTransactionsGridView
        AnalysesPieChart / CategoryBreakdownRow
        ToastView / ToastCard
    }

    ContentView *-- HomeTabView
    ContentView *-- AnalysesTabView
    ContentView *-- CalendrierMainView
    ContentView *-- FutureTabView
    ContentView ..> AddTransactionView
    ContentView ..> WelcomeView
    HomeTabView ..> AddWidgetShortcutView
    HomeTabView ..> AccountPickerView
    AccountPickerView ..> AddAccountSheet
    FutureTabView ..> AddRecurringTransactionView
    AddTransactionView ..> AddCustomTransactionCategorySheet

    ContentView ..> AccountsManager : @Environment
    HomeTabView ..> AccountsManager : @Environment
    AnalysesTabView ..> AccountsManager : @Environment
    CalendrierMainView ..> AccountsManager : @Environment
    FutureTabView ..> AccountsManager : @Environment
```

## Légende

| Notation | Signification |
|---|---|
| `*--` | Composition (cycle de vie lié — suppression en `cascade`) |
| `-->` | Association (lien `nullify`, l'objet survit) |
| `..>` | Dépendance / usage (délégation, injection `@Environment`) |
| `..\|>` | Réalisation d'un protocole |
| `"1" … "0..*"` | Multiplicités (1, 0..1, 0..*) |
| `<<@Model>>` | Entité persistée SwiftData |
| `<<View>>` | Vue SwiftUI |
