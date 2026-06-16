//
//  TransactionsListView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/08/2025.
//

import SwiftUI

struct TransactionsListView: View {
	@Environment(AccountsManager.self) private var accountsManager
	var month: Int? = nil
	var year: Int? = nil
	@State private var showingAccountPicker = false
	@State private var transactionToEdit: Transaction? = nil
	@State private var showingAddTransactionSheet = false
	
	private var sortedTransactions: [Transaction] {
		accountsManager.validatedTransactions(year: year, month: month)
			.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
	}
	
	var body: some View {
		List {
			if sortedTransactions.isEmpty {
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
				ForEach(sortedTransactions) { transaction in
				TransactionRow(transaction: transaction)
					.contentShape(Rectangle())
					.onTapGesture {
						transactionToEdit = transaction
					}
					.swipeActions(edge: .trailing, allowsFullSwipe: true) {
						Button(role: .destructive) {
								accountsManager.deleteTransaction(transaction)
						} label: {
							Label("Supprimer", systemImage: "trash")
						}
					}
			}
			}
		}
		.navigationTitle(titleText)
		.toolbar {
			ToolbarItem(placement: .navigationBarTrailing) {
				Button {
					showingAccountPicker = true
				} label: {
					Image(systemName: "person.crop.circle")
						.font(.title2)
						.accessibilityLabel("Changer de compte")
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
	
	private var titleText: String {
		if let year = year, let month = month {
			return "\(Date.monthName(month)) \(year)"
		} else if let year = year {
			return "\(year)"
		} else {
			return "Transactions"
		}
	}
}
