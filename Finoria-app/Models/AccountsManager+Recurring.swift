//
//  AccountsManager+Recurring.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData

// MARK: - Récurrences (délégué à RecurrenceEngine)
//
// Extension de domaine d'`AccountsManager` (voir AccountsManager.swift).
// CRUD des modèles récurrents ; delete/update/pause purgent d'abord les
// occurrences potentielles encore générées, puis l'engine reprocesse.
extension AccountsManager {

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
}
