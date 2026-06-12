//
//  PotentialTransactionsView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/08/2025.
//

import SwiftUI

struct PotentialTransactionsView: View {
	@Environment(AccountsManager.self) private var accountsManager
	@State private var showingAddTransactionSheet = false
	@State private var transactionToEdit: Transaction? = nil
	@State private var transactionToDelete: Transaction? = nil
	@State private var transactionToValidate: Transaction? = nil
	@State private var showDeleteConfirmation = false
	@State private var showValidateConfirmation = false
	
	// MARK: - Transactions séparées
	
	/// Transactions récurrentes futures, triées par date décroissante (plus récente en haut)
	private var recurringTransactions: [Transaction] {
		accountsManager.potentialTransactions()
			.filter { $0.sourceRecurringTransaction != nil }
			.sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
	}
	
	/// Transactions futures normales, triées par ordre d'ajout inversé (dernière ajoutée en haut)
	private var normalTransactions: [Transaction] {
		accountsManager.potentialTransactions()
			.filter { $0.sourceRecurringTransaction == nil }
			.reversed()
	}
	
	// MARK: - Body
	
	var body: some View {
		List {
			if recurringTransactions.isEmpty && normalTransactions.isEmpty {
				Button {
					showingAddTransactionSheet = true
				} label: {
					Text("Aucune transaction future")
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 40)
				}
				.buttonStyle(.plain)
			} else {
				// Section récurrences
				if !recurringTransactions.isEmpty {
					Section {
						ForEach(recurringTransactions) { transaction in
							transactionRow(for: transaction)
						}
					} header: {
						Text("Transactions récurrentes")
					}
				}
				
				// Section futures normales
				if !normalTransactions.isEmpty {
					Section {
						ForEach(normalTransactions) { transaction in
							transactionRow(for: transaction)
						}
					} header: {
						Text("Futures")
					}
				}
			}
		}
		.navigationTitle("Futur")
		.sheet(isPresented: $showingAddTransactionSheet) {
			AddTransactionView(initialIsPotentiel: true)
		}
		.sheet(item: $transactionToEdit) { transaction in
			AddTransactionView(transactionToEdit: transaction)
		}
		.alert("Supprimer cette transaction ?", isPresented: $showDeleteConfirmation) {
			Button("Annuler", role: .cancel) {
				transactionToDelete = nil
			}
			Button("Supprimer", role: .destructive) {
				if let transaction = transactionToDelete {
					accountsManager.deleteTransaction(transaction)
				}
				transactionToDelete = nil
			}
		} message: {
			Text("Cette transaction a été générée par une récurrence. Elle sera recréée automatiquement au prochain traitement.")
		}
		.alert("Valider cette transaction ?", isPresented: $showValidateConfirmation) {
			Button("Annuler", role: .cancel) {
				transactionToValidate = nil
			}
			Button("Valider") {
				if let transaction = transactionToValidate {
					accountsManager.validateTransaction(transaction)
				}
				transactionToValidate = nil
			}
		} message: {
			Text("Cette transaction a été générée par une récurrence. La valider maintenant l'ajoutera à votre solde actuel.")
		}
	}
	
	// MARK: - Composants
	
	/// Ligne de transaction réutilisable avec swipe actions
	private func transactionRow(for transaction: Transaction) -> some View {
		TransactionRow(transaction: transaction)
			.contentShape(Rectangle())
			.onTapGesture {
				transactionToEdit = transaction
			}
			.swipeActions(edge: .trailing, allowsFullSwipe: true) {
				Button(role: .destructive) {
					if transaction.sourceRecurringTransaction != nil {
						transactionToDelete = transaction
						showDeleteConfirmation = true
					} else {
						accountsManager.deleteTransaction(transaction)
					}
				} label: {
					Label("Supprimer", systemImage: "trash")
				}
			}
			.swipeActions(edge: .leading, allowsFullSwipe: true) {
				Button {
					if transaction.sourceRecurringTransaction != nil {
						transactionToValidate = transaction
						showValidateConfirmation = true
					} else {
						accountsManager.validateTransaction(transaction)
					}
				} label: {
					Label("Valider", systemImage: "checkmark.circle")
				}
				.tint(.green)
			}
	}
}
