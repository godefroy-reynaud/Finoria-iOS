//
//  AccountsManager+Transactions.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData

// MARK: - Gestion des transactions
//
// Extension de domaine d'`AccountsManager` (voir AccountsManager.swift).
// Toutes les écritures s'attachent au compte sélectionné et persistent.
extension AccountsManager {

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

	func transactions() -> [Transaction] {
		selectedAccount?.transactions ?? []
	}
}
