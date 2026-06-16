# Finoria — Data Model

Schéma des entités SwiftData et de leurs relations.

> Rendu automatiquement par GitHub. Pour modifier, éditer le bloc `mermaid` ci-dessous.

```mermaid
erDiagram

    Account {
        UUID    id
        String  name
        String  detail
        String  style
    }

    Transaction {
        UUID    id
        Double  amount
        String  comment
        Bool    potentiel
        Date    date
        String  category
        String  importedCategoryName
    }

    WidgetShortcut {
        UUID    id
        Double  amount
        String  comment
        String  type
        String  category
    }

    RecurringTransaction {
        UUID    id
        Double  amount
        String  comment
        String  type
        String  category
        String  frequency
        Date    startDate
        Date    lastGeneratedDate
        Bool    isPaused
    }

    CustomTransactionCategory {
        UUID    id
        String  name
        String  symbol
        String  colorHex
    }

    Account ||--o{ Transaction               : "1 → 0..* · transactions · cascade"
    Account ||--o{ WidgetShortcut            : "1 → 0..* · widgetShortcuts · cascade"
    Account ||--o{ RecurringTransaction      : "1 → 0..* · recurringTransactions · cascade"
    Account ||--o{ CustomTransactionCategory : "1 → 0..* · customTransactionCategories · cascade"

    Transaction }o--o| CustomTransactionCategory : "0..* → 0..1 · customCategory · nullify"
    Transaction }o--o| RecurringTransaction      : "0..* → 0..1 · sourceRecurringTransaction · nullify"
```

> **Cardinalités** — Mermaid impose la notation « patte d'oie » sur le trait
> (`||` = exactement 1, `o{` = 0..*, `o|` = 0..1). Les multiplicités numériques
> demandées (`1`, `0..*`, `0..1`) sont donc reportées en début de libellé de chaque
> relation. Le diagramme de classes ([CLASS_DIAGRAM.puml](CLASS_DIAGRAM.puml), PlantUML)
> les exprime nativement (`"1" o-- "0..*"`).

## Règles de suppression

| Relation | Règle | Conséquence |
|---|---|---|
| `Account → Transaction` | cascade | Supprimer un compte supprime toutes ses transactions |
| `Account → WidgetShortcut` | cascade | Supprimer un compte supprime tous ses raccourcis |
| `Account → RecurringTransaction` | cascade | Supprimer un compte supprime toutes ses récurrences |
| `Account → CustomTransactionCategory` | cascade | Supprimer un compte supprime toutes ses catégories perso |
| `CustomTransactionCategory → Transaction` | nullify | Supprimer une catégorie met `customCategory = nil` sur les transactions (elles sont conservées) |
| `RecurringTransaction → Transaction` | nullify | Supprimer une récurrence conserve les transactions déjà générées (historique) |

## Stockage

| Données | Où | Synchronisation |
|---|---|---|
| Comptes, transactions, raccourcis, récurrences, catégories | SQLite via SwiftData | CloudKit (iCloud) automatique |
| Compte sélectionné | `UserDefaults` | Non synchronisé — préférence locale |
