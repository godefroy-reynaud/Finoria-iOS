//
//  AccountsManager+CustomCategories.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData

// MARK: - Catégories personnalisées (transactions)
//
// Extension de domaine d'`AccountsManager` (voir AccountsManager.swift).
// CRUD des catégories personnalisées par compte ; l'ajout/la mise à jour
// re-lient les transactions importées (CSV) dont le libellé correspond.
extension AccountsManager {

	func customTransactionCategories() -> [CustomTransactionCategory] {
		guard let account = selectedAccount else { return [] }
		return account.customTransactionCategories ?? []
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

	// WHY: privée à ce fichier — seul le CRUD des catégories ci-dessus l'utilise.
	private func relinkImportedTransactions(in account: Account, to customCategory: CustomTransactionCategory) {
		let target = Self.normalizeCategoryName(customCategory.name)
		guard !target.isEmpty else { return }

		for transaction in (account.transactions ?? []) {
			guard transaction.customCategory == nil,
				let importedName = transaction.importedCategoryName,
				Self.normalizeCategoryName(importedName) == target else {
				continue
			}

			transaction.customCategory = customCategory
			transaction.category = .other
			transaction.importedCategoryName = nil
		}
	}
}
