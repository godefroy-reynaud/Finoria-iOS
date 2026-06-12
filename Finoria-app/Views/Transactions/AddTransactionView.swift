//
//  AddTransactionView.swift
//  GDF-app
//
//  Created by Godefroy REYNAUD on 16/10/2024.
//

import SwiftUI

struct AddTransactionView: View {
	@Environment(\.dismiss) var dismiss
	@Environment(AccountsManager.self) private var accountsManager

	// Transaction à éditer (nil = nouvelle transaction)
	var transactionToEdit: Transaction? = nil

	/// Valeur initiale du toggle "potentiel" pour une nouvelle transaction
	var initialIsPotentiel: Bool = false
	var initialTransactionType: TransactionType = .expense

	// MARK: - Limites
	private let maxCommentLength = 30
	private let maxMontant: Double = 999_999_999.99

	// MARK: - State
	@State private var montant: Double? = nil
	@State private var transactionComment: String = ""
	@State private var transactionType: TransactionType = .expense
	@State private var transactionDate: Date = Date()
	@State private var isPotentiel: Bool = false
	@State private var selectedCategory: TransactionCategory = .expense
	@State private var selectedCustomCategoryId: UUID?
	@State private var hasManuallySelectedCategory = false
	@State private var showingErrorAlert = false
	@State private var errorMessage = ""

	private var isEditMode: Bool { transactionToEdit != nil }

	var body: some View {
		NavigationView {
			Form {
				Section("Type de transaction") {
					Picker("Type", selection: $transactionType) {
						ForEach(TransactionType.allCases) { type in
							Text(type.label).tag(type)
						}
					}
					.pickerStyle(.segmented)
					.onChange(of: transactionType) { _, newValue in
						if !isEditMode && !hasManuallySelectedCategory && selectedCustomCategoryId == nil && (selectedCategory == .income || selectedCategory == .expense) {
							selectedCategory = newValue == .income ? .income : .expense
						}
					}
				}

				Section {
					CurrencyTextField("Montant", amount: $montant)

					TextField("Commentaire", text: $transactionComment)
						.onChange(of: transactionComment) { _, newValue in
							if newValue.count > maxCommentLength {
								transactionComment = String(newValue.prefix(maxCommentLength))
							}
							if !isEditMode && !hasManuallySelectedCategory && selectedCustomCategoryId == nil {
								selectedCategory = TransactionCategory.guessFrom(comment: newValue, type: transactionType)
							}
						}
				} header: {
					Text("Détails")
				} footer: {
					HStack {
						Spacer()
						Text("\(transactionComment.count)/\(maxCommentLength)")
					}
				}

				Section("Catégorie") {
					TransactionCategoryPicker(
						selectedStyle: $selectedCategory,
						selectedCustomCategoryId: $selectedCustomCategoryId
					) {
						hasManuallySelectedCategory = true
					}
				}

				Section("Date et statut") {
					Toggle("Transaction future", isOn: $isPotentiel)
					if !isPotentiel {
						DatePicker("Date", selection: $transactionDate, displayedComponents: .date)
							.datePickerStyle(.graphical)
					}
				}

				if isEditMode {
					Section {
						Button(role: .destructive) {
							if let transaction = transactionToEdit {
								accountsManager.deleteTransaction(transaction)
								dismiss()
							}
						} label: {
							HStack {
								Spacer()
								Label("Supprimer", systemImage: "trash")
								Spacer()
							}
						}
					}
				}
			}
			.navigationTitle(isEditMode ? "Modifier" : "Nouvelle transaction")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Annuler") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isEditMode ? "OK" : "Ajouter") {
						saveTransaction()
					}
				}
			}
			.alert("Erreur", isPresented: $showingErrorAlert) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(errorMessage)
			}
			.onAppear {
				if let t = transactionToEdit {
					montant = abs(t.amount)
					transactionComment = t.comment
					transactionType = t.amount >= 0 ? .income : .expense
					isPotentiel = t.potentiel
					transactionDate = t.date ?? Date()
					if let customCategory = t.customCategory {
						selectedCategory = .other
						selectedCustomCategoryId = customCategory.id
					} else {
						selectedCategory = t.category
						selectedCustomCategoryId = nil
					}
				} else {
					isPotentiel = initialIsPotentiel
					transactionType = initialTransactionType
					if !hasManuallySelectedCategory {
						selectedCategory = initialTransactionType == .income ? .income : .expense
						selectedCustomCategoryId = nil
					}
				}
			}
		}
	}

	private func saveTransaction() {
		guard let m = montant, m > 0 else {
			errorMessage = "Veuillez entrer un montant positif."
			showingErrorAlert = true
			return
		}

		let trimmedComment = transactionComment.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedComment.isEmpty else {
			errorMessage = "Veuillez entrer un commentaire."
			showingErrorAlert = true
			return
		}

		if m > maxMontant {
			errorMessage = "Montant maximum : \(maxMontant.formatted()) €"
			showingErrorAlert = true
			return
		}

		let finalAmount = transactionType == .income ? m : -m
		let finalComment = String(transactionComment.prefix(maxCommentLength))
		let finalDate: Date? = isPotentiel ? nil : transactionDate
		let customCategory = selectedCustomCategoryId.flatMap { accountsManager.customTransactionCategory(with: $0) }
		let builtInCategory: TransactionCategory = customCategory == nil ? selectedCategory : .other

		if let existingTransaction = transactionToEdit {
			accountsManager.updateTransaction(
				existingTransaction,
				amount: finalAmount,
				comment: finalComment,
				potentiel: isPotentiel,
				date: finalDate,
				category: builtInCategory,
				customCategory: customCategory
			)
		} else {
			accountsManager.addTransaction(Transaction(
				amount: finalAmount,
				comment: finalComment,
				potentiel: isPotentiel,
				date: finalDate,
				category: builtInCategory,
				customCategory: customCategory
			))
		}
		dismiss()
	}
}
