//
//  AccountsManager.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData
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
class AccountsManager: ObservableObject {
	
	// MARK: - Logger
	
	private static let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "com.finoria",
		category: "AccountsManager"
	)
	
	// MARK: - Dependencies
	
	let modelContext: ModelContext
	
	// MARK: - État publié (Single Source of Truth)
	
	@Published private(set) var accounts: [Account] = []
	@Published var selectedAccountId: UUID? {
		didSet { saveSelectedAccountId() }
	}
	
	/// Dernière erreur de persistance (pour affichage UI si nécessaire)
	@Published var lastPersistenceError: String?
	
	/// Compte actuellement sélectionné (dérivé de selectedAccountId)
	var selectedAccount: Account? {
		accounts.first { $0.id == selectedAccountId }
	}
	
	// MARK: - Init
	
	init(modelContext: ModelContext) {
		self.modelContext = modelContext
		fetchAccounts()
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
	
	/// Sauvegarde le contexte SwiftData et rafraîchit la liste des comptes.
	///
	/// CloudKit : `modelContext.save()` déclenche la synchronisation automatique.
	/// En cas de conflit, SwiftData utilise la politique de merge par défaut (server wins).
	/// Les erreurs sont loguées via os.log pour le diagnostic.
	private func persist() {
		do {
			try modelContext.save()
			lastPersistenceError = nil
		} catch {
			Self.logger.error("Échec sauvegarde SwiftData: \(error.localizedDescription)")
			lastPersistenceError = error.localizedDescription
		}
		fetchAccounts()
	}
	
	/// Recharge la liste des comptes depuis SwiftData et valide la sélection.
	///
	/// Appelé après chaque mutation et au retour au premier plan
	/// pour récupérer les changements synchronisés via CloudKit.
	private func fetchAccounts() {
		let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)])
		do {
			accounts = try modelContext.fetch(descriptor)
			lastPersistenceError = nil
		} catch {
			Self.logger.error("Échec chargement des comptes: \(error.localizedDescription)")
			lastPersistenceError = error.localizedDescription
			// Ne pas écraser accounts avec [] en cas d'erreur temporaire
			// pour éviter de montrer un écran vide alors que les données existent
		}
		
		// Vérifier que le compte sélectionné existe toujours
		if let id = selectedAccountId, !accounts.contains(where: { $0.id == id }) {
			// Le compte a été supprimé (ex: sync CloudKit) → réinitialiser
			selectedAccountId = accounts.first?.id
		}
	}
	
	// MARK: - Persistance du compte sélectionné (UserDefaults — préférence UI)
	
	private func saveSelectedAccountId() {
		if let id = selectedAccountId {
			UserDefaults.standard.set(id.uuidString, forKey: "lastSelectedAccountId")
		} else {
			UserDefaults.standard.removeObject(forKey: "lastSelectedAccountId")
		}
	}
	
	private func loadSelectedAccountId() -> UUID? {
		guard let idString = UserDefaults.standard.string(forKey: "lastSelectedAccountId") else { return nil }
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
		
		if accounts.isEmpty {
			selectedAccountId = nil
		} else if wasSelected {
			selectedAccountId = accounts.first?.id
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
	
	func getAllAccounts() -> [Account] {
		accounts
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
		if RecurrenceEngine.processAll(accounts: accounts, context: modelContext) {
			persist()
		}
	}
	
	/// Sauvegarde publique pour besoins externes
	func saveData() {
		persist()
	}
	
	/// Rafraîchit les données depuis le store SwiftData.
	/// Appelé quand l'app revient au premier plan pour récupérer les changements CloudKit.
	func refreshFromStore() {
		Self.logger.info("Rafraîchissement depuis le store (CloudKit sync)")
		fetchAccounts()
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
