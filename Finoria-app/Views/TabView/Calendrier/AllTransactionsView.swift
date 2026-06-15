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
				DayGroupedTransactionSections(transactions: allTransactions) { transaction in
					transactionToEdit = transaction
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