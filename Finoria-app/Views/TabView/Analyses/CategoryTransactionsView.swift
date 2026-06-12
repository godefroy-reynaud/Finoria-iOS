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
	let month: Int
	let year: Int
	
	@State private var transactionToEdit: Transaction? = nil
	
	/// Transactions validées de cette catégorie pour le mois sélectionné, triées par date décroissante
	private var categoryTransactions: [Transaction] {
		accountsManager.validatedTransactions(year: year, month: month)
			.filter { $0.category == category }
			.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
	}
	
	/// Regroupe les transactions par jour
	private var transactionsGroupedByDay: [(date: Date, transactions: [Transaction])] {
		let calendar = Calendar.current
		let grouped = Dictionary(grouping: categoryTransactions) { transaction -> Date in
			guard let date = transaction.date else { return Date.distantPast }
			return calendar.startOfDay(for: date)
		}
		return grouped.sorted { $0.key > $1.key }
			.map { (date: $0.key, transactions: $0.value) }
	}
	
	var body: some View {
		Group {
			if categoryTransactions.isEmpty {
				VStack(spacing: 12) {
					StyleIconView(style: category, size: 56)
					Text("Aucune transaction")
						.font(.headline)
						.foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				List {
					ForEach(transactionsGroupedByDay, id: \.date) { group in
						Section {
							ForEach(group.transactions) { transaction in
								TransactionRow(transaction: transaction)
									.contentShape(Rectangle())
									.onTapGesture {
										transactionToEdit = transaction
									}
									.swipeActions(edge: .trailing, allowsFullSwipe: true) {
										Button(role: .destructive) {
											withAnimation {
												accountsManager.deleteTransaction(transaction)
											}
										} label: {
											Label("Supprimer", systemImage: "trash")
										}
									}
							}
						} header: {
							Text(group.date.dayHeaderFormatted())
								.font(.subheadline)
								.fontWeight(.semibold)
								.foregroundStyle(.secondary)
						}
					}
				}
			}
		}
		.navigationTitle(category.label)
		.sheet(item: $transactionToEdit) { transaction in
			AddTransactionView(transactionToEdit: transaction)
		}
	}

}

#Preview {
	NavigationStack {
		CategoryTransactionsView(
			category: .food,
			month: 2,
			year: 2026
		)
	}
	.environment(AccountsManager.preview)
}
