//
//  AccountsManager+Shortcuts.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData

// MARK: - Raccourcis (Widget Shortcuts)
//
// Extension de domaine d'`AccountsManager` (voir AccountsManager.swift).
// CRUD des raccourcis « une tape » du compte sélectionné.
extension AccountsManager {

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
}
