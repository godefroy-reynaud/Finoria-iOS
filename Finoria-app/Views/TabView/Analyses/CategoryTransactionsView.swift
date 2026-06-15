//
//  CategoryTransactionsView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 12/02/2026.
//

import SwiftUI

/// Affiche les transactions d'une catégorie donnée, regroupées par jour
/// (même présentation que AllTransactionsView)
struct CategoryTransactionsView: View {
	@Environment(AccountsManager.self) private var accountsManager
	let category: TransactionCategory
	/// Identifiant de la catégorie personnalisée si la catégorie en est une, sinon `nil`.
	let customCategoryId: UUID?
	let month: Int
	let year: Int

	@State private var transactionToEdit: Transaction? = nil

	/// Indique si une transaction appartient à la catégorie affichée.
	/// Pour une catégorie personnalisée on compare l'identifiant ; pour une
	/// catégorie intégrée on exige l'absence de catégorie personnalisée.
	private func belongs(_ transaction: Transaction) -> Bool {
		if let customCategoryId {
			return transaction.customCategory?.id == customCategoryId
		}
		return transaction.customCategory == nil && transaction.category == category
	}

	/// Catégorie personnalisée résolue (pour le titre et l'icône), si applicable.
	private var customCategory: CustomTransactionCategory? {
		customCategoryId.flatMap { accountsManager.customTransactionCategory(with: $0) }
	}

	private var displayLabel: String { customCategory?.name ?? category.label }
	private var displayIcon: String { customCategory?.symbol ?? category.icon }
	private var displayColor: Color { customCategory?.resolvedColor ?? category.color }

	/// Transactions validées de cette catégorie pour le mois sélectionné, triées par date décroissante
	private var categoryTransactions: [Transaction] {
		accountsManager.validatedTransactions(year: year, month: month)
			.filter { belongs($0) }
			.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
	}

	var body: some View {
		Group {
			if categoryTransactions.isEmpty {
				VStack(spacing: 12) {
					CategoryIconView(icon: displayIcon, color: displayColor, size: 56)
					Text("Aucune transaction")
						.font(.headline)
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				List {
					DayGroupedTransactionSections(transactions: categoryTransactions) { transaction in
						transactionToEdit = transaction
					}
				}
			}
		}
		.navigationTitle(displayLabel)
		.sheet(item: $transactionToEdit) { transaction in
			AddTransactionView(transactionToEdit: transaction)
		}
	}

}

#Preview {
	NavigationStack {
		CategoryTransactionsView(
			category: .food,
			customCategoryId: nil,
			month: 2,
			year: 2026
		)
	}
	.environment(AccountsManager.preview)
}
