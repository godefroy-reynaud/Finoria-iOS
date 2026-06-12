//
//  AccountsManager.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData
import Observation
import os.log

/// Orchestrateur central de l'application.
///
/// **Règle d'or** : Toute modification de données DOIT passer par cette classe.
///
/// Responsabilités :
/// - Maintenir l'état observable pour SwiftUI
/// - Orchestrer les appels aux services spécialisés
/// - Garantir la persistance SwiftData après chaque mutation
///
/// Délègue à :
/// - `SwiftData ModelContext` pour la persistance
/// - `RecurrenceEngine` pour le traitement des récurrences
/// - `CalculationService` pour les calculs financiers
/// - `CSVService` pour l'import/export CSV
// WHY: @MainActor garantit que toutes les mutations SwiftData et l'état observé
// se font sur le main thread (requis par ModelContext.mainContext et SwiftUI).
// Rend aussi la classe implicitement Sendable (nécessaire pour Transferable/ShareLink).
//
// WHY: @Observable (iOS 17) remplace ObservableObject : SwiftUI ne redessine que
// les vues qui lisent réellement la propriété modifiée, au lieu de redessiner
// toutes les vues abonnées à chaque changement de n'importe quelle @Published.
@MainActor
@Observable
class AccountsManager {
	
	// MARK: - Logger
	
	private static let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "com.finoria",
		category: "AccountsManager"
	)
	
	// MARK: - Dependencies
	
	let modelContext: ModelContext
	
	// MARK: - État observé (Single Source of Truth)

	// WHY: Avec @Observable, plus besoin de @Published — toute propriété stockée
	// est automatiquement suivie, avec un tracking par propriété (plus fin).
	// WHY: Le tableau `accounts` en mémoire a été supprimé — les listes de comptes
	// sont lues par @Query directement dans les vues (lazy loading SwiftData).
	var selectedAccountId: UUID? {
		didSet { saveSelectedAccountId() }
	}

	/// Dernière erreur de persistance (pour affichage UI si nécessaire)
	var lastPersistenceError: String?
	
	/// Compte actuellement sélectionné (dérivé de selectedAccountId)
	// WHY: Fetch ciblé (fetchLimit = 1) au lieu d'une recherche dans le tableau
	// mémoire — SwiftData résout l'objet depuis son cache, pas de coût notable.
	var selectedAccount: Account? {
		guard let id = selectedAccountId else { return nil }
		var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
		descriptor.fetchLimit = 1
		return (try? modelContext.fetch(descriptor))?.first
	}
	
	// MARK: - Init
	
	init(modelContext: ModelContext) {
		self.modelContext = modelContext
		selectedAccountId = loadSelectedAccountId()
	}
	
	// MARK: - Preview Helper
	
	/// Crée un AccountsManager avec un conteneur en mémoire pour les Previews
	@MainActor
	static var preview: AccountsManager {
		do {
			let container = try SwiftDataService.makePreviewContainer()
			return AccountsManager(modelContext: container.mainContext)
		} catch {
			fatalError("Failed to create preview container: \(error)")
		}
	}
	
	// MARK: - Persistance interne
	
	/// Sauvegarde le contexte SwiftData.
	///
	/// CloudKit : `modelContext.save()` déclenche la synchronisation automatique.
	/// En cas de conflit, SwiftData utilise la politique de merge par défaut (server wins).
	/// Les erreurs sont loguées via os.log pour le diagnostic.
	// WHY: Plus de re-fetch manuel après chaque save — les vues @Query et les
	// @Model observés par SwiftUI se mettent à jour automatiquement.
	private func persist() {
		do {
			try modelContext.save()
			lastPersistenceError = nil
		} catch {
			Self.logger.error("Échec sauvegarde SwiftData: \(error.localizedDescription)")
			lastPersistenceError = error.localizedDescription
		}
	}

	/// Premier compte (tri par nom), ou nil s'il n'en reste aucun
	private func firstAccount() -> Account? {
		var descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)])
		descriptor.fetchLimit = 1
		return (try? modelContext.fetch(descriptor))?.first
	}
	
	// MARK: - Persistance du compte sélectionné (UserDefaults — préférence UI)
	
	// WHY: Clé centralisée dans AppStorageKeys — une faute de frappe dans une
	// clé dupliquée serait un bug silencieux (sélection jamais restaurée).
	private func saveSelectedAccountId() {
		if let id = selectedAccountId {
			UserDefaults.standard.set(id.uuidString, forKey: AppStorageKeys.lastSelectedAccountId)
		} else {
			UserDefaults.standard.removeObject(forKey: AppStorageKeys.lastSelectedAccountId)
		}
	}

	private func loadSelectedAccountId() -> UUID? {
		guard let idString = UserDefaults.standard.string(forKey: AppStorageKeys.lastSelectedAccountId) else { return nil }
		return UUID(uuidString: idString)
	}
	
	// MARK: - Gestion des comptes
	
	func addAccount(_ account: Account) {
		modelContext.insert(account)
		persist()
	}
	
	func deleteAccount(_ account: Account) {
		let wasSelected = selectedAccountId == account.id
		modelContext.delete(account) // cascade : supprime transactions, raccourcis, récurrences
		persist()

		// WHY: Re-fetch du premier compte restant (plus de tableau en mémoire)
		// pour basculer la sélection ou la vider s'il n'y a plus de compte.
		let remaining = firstAccount()
		if remaining == nil {
			selectedAccountId = nil
		} else if wasSelected {
			selectedAccountId = remaining?.id
		}
	}
	
	func updateAccount(_ account: Account, name: String, detail: String, style: AccountStyle) {
		account.name = name
		account.detail = detail
		account.style = style
		persist()
	}
	
	func resetAccount(_ account: Account) {
		for transaction in account.transactions {
			modelContext.delete(transaction)
		}
		persist()
	}
	
	// MARK: - Gestion des transactions
	
	func addTransaction(_ transaction: Transaction) {
		guard let account = selectedAccount else { return }
		transaction.account = account
		modelContext.insert(transaction)
		persist()
	}
	
	func deleteTransaction(_ transaction: Transaction) {
		modelContext.delete(transaction)
		persist()
	}
	
	func validateTransaction(_ transaction: Transaction) {
		transaction.validate(at: Date())
		persist()
	}
	
	func updateTransaction(
		_ transaction: Transaction,
		amount: Double,
		comment: String,
		potentiel: Bool,
		date: Date?,
		category: TransactionCategory,
		customCategory: CustomTransactionCategory? = nil
	) {
		transaction.amount = amount
		transaction.comment = comment
		transaction.potentiel = potentiel
		transaction.date = date
		transaction.category = category
		transaction.customCategory = customCategory
		if customCategory != nil {
			transaction.importedCategoryName = nil
		}
		persist()
	}

	// MARK: - Catégories personnalisées (transactions)

	func customTransactionCategories() -> [CustomTransactionCategory] {
		guard let account = selectedAccount else { return [] }
		return account.customTransactionCategories
	}

	func customTransactionCategory(with id: UUID) -> CustomTransactionCategory? {
		customTransactionCategories().first { $0.id == id }
	}

	func addCustomTransactionCategory(name: String, symbol: String, colorHex: String) -> CustomTransactionCategory? {
		guard let account = selectedAccount else { return nil }
		let category = CustomTransactionCategory(name: name, symbol: symbol, colorHex: colorHex)
		category.account = account
		modelContext.insert(category)
		relinkImportedTransactions(in: account, to: category)
		persist()
		return category
	}

	func updateCustomTransactionCategory(_ category: CustomTransactionCategory, name: String, symbol: String, colorHex: String) {
		category.name = name
		category.symbol = symbol
		category.colorHex = colorHex
		if let account = category.account {
			relinkImportedTransactions(in: account, to: category)
		}
		persist()
	}

	func deleteCustomTransactionCategory(_ category: CustomTransactionCategory) {
		modelContext.delete(category)
		persist()
	}
	
	func transactions() -> [Transaction] {
		selectedAccount?.transactions ?? []
	}
	
	// MARK: - Calculs (délégués à CalculationService)
	
	func totalNonPotential(for account: Account) -> Double {
		CalculationService.totalNonPotential(transactions: account.transactions)
	}
	
	func totalPotential(for account: Account) -> Double {
		CalculationService.totalPotential(transactions: account.transactions)
	}
	
	func availableYears() -> [Int] {
		CalculationService.availableYears(transactions: transactions())
	}
	
	func totalForYear(_ year: Int) -> Double {
		CalculationService.totalForYear(year, transactions: transactions())
	}
	
	func totalForMonth(_ month: Int, year: Int) -> Double {
		CalculationService.totalForMonth(month, year: year, transactions: transactions())
	}
	
	func monthlyChangePercentage() -> Double? {
		CalculationService.monthlyChangePercentage(transactions: transactions())
	}
	
	// MARK: - Filtres (délégués à CalculationService)
	
	func potentialTransactions() -> [Transaction] {
		CalculationService.potentialTransactions(from: transactions())
	}
	
	func validatedTransactions(year: Int? = nil, month: Int? = nil) -> [Transaction] {
		CalculationService.validatedTransactions(from: transactions(), year: year, month: month)
	}
	
	// MARK: - Raccourcis (Widget Shortcuts)
	
	func getWidgetShortcuts() -> [WidgetShortcut] {
		selectedAccount?.widgetShortcuts ?? []
	}
	
	func addWidgetShortcut(_ shortcut: WidgetShortcut) {
		guard let account = selectedAccount else { return }
		shortcut.account = account
		modelContext.insert(shortcut)
		persist()
	}
	
	func deleteWidgetShortcut(_ shortcut: WidgetShortcut) {
		modelContext.delete(shortcut)
		persist()
	}
	
	func updateWidgetShortcut(
		_ shortcut: WidgetShortcut,
		amount: Double,
		comment: String,
		type: TransactionType,
		category: TransactionCategory,
		customCategory: CustomTransactionCategory? = nil
	) {
		shortcut.amount = amount
		shortcut.comment = comment
		shortcut.type = type
		shortcut.category = category
		shortcut.customCategory = customCategory
		persist()
	}
	
	// MARK: - CSV (délégué à CSVService)
	
	func generateCSV() -> URL? {
		guard let account = selectedAccount else { return nil }
		return CSVService.generateCSV(transactions: account.transactions, accountName: account.name)
	}
	
	func importCSV(from url: URL) -> Int {
		guard let account = selectedAccount else { return 0 }
		let imported = CSVService.importCSV(from: url)
		for tx in imported {
			if let importedName = tx.importedCategoryName,
				let matchedCustom = account.customTransactionCategories.first(where: {
					normalizeCategoryName($0.name) == normalizeCategoryName(importedName)
				}) {
				tx.customCategory = matchedCustom
				tx.category = .other
				tx.importedCategoryName = nil
			}
			tx.account = account
			modelContext.insert(tx)
		}
		if !imported.isEmpty { persist() }
		return imported.count
	}
	
	// MARK: - Récurrences (délégué à RecurrenceEngine)
	
	func getRecurringTransactions() -> [RecurringTransaction] {
		selectedAccount?.recurringTransactions ?? []
	}
	
	func addRecurringTransaction(_ recurring: RecurringTransaction) {
		guard let account = selectedAccount else { return }
		recurring.account = account
		modelContext.insert(recurring)
		persist()
		processRecurringTransactions()
	}
	
	func deleteRecurringTransaction(_ recurring: RecurringTransaction) {
		RecurrenceEngine.removePotentialTransactions(for: recurring, context: modelContext)
		modelContext.delete(recurring)
		persist()
	}
	
	func updateRecurringTransaction(
		_ recurring: RecurringTransaction,
		amount: Double,
		comment: String,
		type: TransactionType,
		category: TransactionCategory,
		customCategory: CustomTransactionCategory? = nil,
		frequency: RecurrenceFrequency,
		startDate: Date
	) {
		RecurrenceEngine.removePotentialTransactions(for: recurring, context: modelContext)
		recurring.amount = amount
		recurring.comment = comment
		recurring.type = type
		recurring.category = category
		recurring.customCategory = customCategory
		recurring.frequency = frequency
		recurring.startDate = startDate
		recurring.lastGeneratedDate = nil
		persist()
		processRecurringTransactions()
	}
	
	func pauseRecurringTransaction(_ recurring: RecurringTransaction) {
		RecurrenceEngine.removePotentialTransactions(for: recurring, context: modelContext)
		recurring.isPaused = true
		persist()
	}
	
	func resumeRecurringTransaction(_ recurring: RecurringTransaction) {
		let calendar = Calendar.current
		// WHY: Replaced force unwrap with guard let to prevent runtime crashes if date calculation fails (e.g. edge cases)
		guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) else {
			Self.logger.warning("Failed to calculate yesterday's date.")
			return
		}
		recurring.isPaused = false
		recurring.lastGeneratedDate = yesterday
		persist()
		processRecurringTransactions()
	}
	
	/// Traite toutes les récurrences : génère les transactions à venir et valide celles du passé.
	/// Appelé au lancement, au retour au premier plan, et après ajout/modification de récurrence.
	func processRecurringTransactions() {
		// WHY: Fetch ponctuel pour le traitement — les comptes ne sont plus
		// conservés en mémoire dans le manager.
		let allAccounts = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
		if RecurrenceEngine.processAll(accounts: allAccounts, context: modelContext) {
			persist()
		}
	}
	
	/// Sauvegarde publique pour besoins externes
	func saveData() {
		persist()
	}
	
	/// Valide la sélection au retour au premier plan (changements CloudKit).
	// WHY: Les vues @Query se rafraîchissent automatiquement depuis le store —
	// il reste seulement à vérifier que le compte sélectionné existe toujours
	// (il a pu être supprimé sur un autre appareil via CloudKit).
	func refreshFromStore() {
		Self.logger.info("Rafraîchissement depuis le store (CloudKit sync)")
		if selectedAccountId != nil && selectedAccount == nil {
			selectedAccountId = firstAccount()?.id
		}
	}

	private func relinkImportedTransactions(in account: Account, to customCategory: CustomTransactionCategory) {
		let target = normalizeCategoryName(customCategory.name)
		guard !target.isEmpty else { return }

		for transaction in account.transactions {
			guard transaction.customCategory == nil,
				let importedName = transaction.importedCategoryName,
				normalizeCategoryName(importedName) == target else {
				continue
			}

			transaction.customCategory = customCategory
			transaction.category = .other
			transaction.importedCategoryName = nil
		}
	}

	private func normalizeCategoryName(_ value: String) -> String {
		value
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
	}
}
