//
//  AllTransactionsView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/02/2026.
//

import SwiftUI

struct AllTransactionsView: View {
	@Environment(AccountsManager.self) private var accountsManager
	var embedded: Bool = false // Si true, pas de titre ni toolbar (utilisé dans CalendrierTabView)
	
	@State private var showingAccountPicker = false
	@State private var transactionToEdit: Transaction? = nil
	@State private var showingAddTransactionSheet = false
	
	/// Toutes les transactions validées, triées par date décroissante
	private var allTransactions: [Transaction] {
		accountsManager.validatedTransactions(year: nil, month: nil)
			.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
	}
	
	/// Regroupe les transactions par jour
	private var transactionsGroupedByDay: [(date: Date, transactions: [Transaction])] {
		let calendar = Calendar.current
		let grouped = Dictionary(grouping: allTransactions) { transaction -> Date in
			guard let date = transaction.date else { return Date.distantPast }
			return calendar.startOfDay(for: date)
		}
		return grouped.sorted { $0.key > $1.key }
			.map { (date: $0.key, transactions: $0.value) }
	}
	
	var body: some View {
		List {
			if allTransactions.isEmpty {
				Button {
					showingAddTransactionSheet = true
				} label: {
					Text("Aucune transaction")
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 40)
				}
				.buttonStyle(.plain)
			} else {
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
		.scrollContentBackground(embedded ? .hidden : .visible)
		.if(!embedded) { view in
			view
				.navigationTitle("Toutes les transactions")
				.toolbar {
					ToolbarItem(placement: .navigationBarTrailing) {
						Button {
							showingAccountPicker = true
						} label: {
							Image(systemName: "person.crop.circle")
								.font(.title2)
						}
					}
				}
		}
		.sheet(isPresented: $showingAccountPicker) {
			AccountPickerView()
		}
		.sheet(item: $transactionToEdit) { transaction in
			AddTransactionView(transactionToEdit: transaction)
		}
		.sheet(isPresented: $showingAddTransactionSheet) {
			AddTransactionView()
		}
	
	}
}