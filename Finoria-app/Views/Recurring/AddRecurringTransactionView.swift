//
//  AddRecurringTransactionView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 10/02/2026.
//

import SwiftUI

struct AddRecurringTransactionView: View {
	@Environment(\.dismiss) var dismiss
	@Environment(AccountsManager.self) private var accountsManager
	
	// Récurrence à éditer (nil = nouvelle récurrence)
	var recurringToEdit: RecurringTransaction? = nil
	
	// MARK: - Limites
	private let maxCommentLength = 20
	
	// MARK: - State
	@State private var amount: Double?
	@State private var comment = ""
	@State private var type: TransactionType = .expense
	@State private var selectedCategory: TransactionCategory = .other
	@State private var selectedCustomCategoryId: UUID?
	@State private var frequency: RecurrenceFrequency = .monthly
	@State private var startDate: Date = Date()
	@State private var showError = false
	@State private var errorMessage = ""
	@State private var hasManuallySelectedCategory = false
	
	private var isEditMode: Bool { recurringToEdit != nil }
	
	// MARK: - Body
	
	var body: some View {
		NavigationStack {
			Form {
				// MARK: - Montant et commentaire
				Section {
					CurrencyTextField("Montant", amount: $amount)
					
					TextField("Commentaire", text: $comment)
						.onChange(of: comment) { _, newValue in
							if newValue.count > maxCommentLength {
								comment = String(newValue.prefix(maxCommentLength))
							}
							if !isEditMode && !hasManuallySelectedCategory {
								if selectedCustomCategoryId == nil {
									selectedCategory = TransactionCategory.guessFrom(comment: newValue, type: type)
								}
							}
						}
				} footer: {
					HStack {
						Spacer()
						Text("\(comment.count)/\(maxCommentLength)")
					}
				}
				
				// MARK: - Type
				Picker("Type", selection: $type) {
					ForEach(TransactionType.allCases) { t in
						Text(t.label).tag(t)
					}
				}
				.pickerStyle(.segmented)
				.onChange(of: type) { _, newValue in
					if !isEditMode && !hasManuallySelectedCategory && selectedCustomCategoryId == nil && (selectedCategory == .salary || selectedCategory == .other) {
						selectedCategory = newValue == .income ? .salary : .other
					}
				}
				
				// MARK: - Fréquence
				Section("Récurrence") {
					Picker("Fréquence", selection: $frequency) {
						ForEach(RecurrenceFrequency.allCases) { freq in
							Text(freq.label).tag(freq)
						}
					}
					
					DatePicker("À partir du", selection: $startDate, displayedComponents: .date)
						.datePickerStyle(.compact)
				}
				
				// MARK: - Sélecteur d'icône
				Section("Catégorie") {
					TransactionCategoryPicker(
						selectedStyle: $selectedCategory,
						selectedCustomCategoryId: $selectedCustomCategoryId
					) {
						hasManuallySelectedCategory = true
					}
				}
				
				// Bouton supprimer en mode édition
				if isEditMode {
					Section {
						Button(role: .destructive) {
							if let recurring = recurringToEdit {
								accountsManager.deleteRecurringTransaction(recurring)
								dismiss()
							}
						} label: {
							HStack {
								Spacer()
								Label("Supprimer la récurrence", systemImage: "trash")
								Spacer()
							}
						}
					}
				}
			}
			.navigationTitle(isEditMode ? "Modifier la récurrence" : "Nouvelle récurrence")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Annuler") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isEditMode ? "OK" : "Ajouter") {
						saveRecurring()
					}
				}
			}
			.alert("Erreur", isPresented: $showError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(errorMessage)
			}
			.onAppear {
			if let recurring = recurringToEdit {
					amount = recurring.amount
					comment = recurring.comment
					type = recurring.type
					if let customCategory = recurring.customCategory {
						selectedCategory = .other
						selectedCustomCategoryId = customCategory.id
					} else {
						selectedCategory = recurring.category
						selectedCustomCategoryId = nil
					}
					frequency = recurring.frequency
					startDate = recurring.startDate
				}
			}
		}
	}
	
	// MARK: - Save
	
	private func saveRecurring() {
		guard let amount = amount, amount > 0 else {
			errorMessage = "Veuillez entrer un montant positif."
			showError = true
			return
		}
		
		let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedComment.isEmpty else {
			errorMessage = "Veuillez entrer un commentaire."
			showError = true
			return
		}
		
		let customCategory = selectedCustomCategoryId.flatMap { accountsManager.customTransactionCategory(with: $0) }
		let builtInCategory: TransactionCategory = customCategory == nil ? selectedCategory : .other

		if let existing = recurringToEdit {
			// Mode édition: mutation en place de l'objet SwiftData
			accountsManager.updateRecurringTransaction(
				existing,
				amount: amount,
				comment: comment,
				type: type,
				category: builtInCategory,
				customCategory: customCategory,
				frequency: frequency,
				startDate: startDate
			)
		} else {
			let recurring = RecurringTransaction(
				amount: amount,
				comment: comment,
				type: type,
				category: builtInCategory,
				customCategory: customCategory,
				frequency: frequency,
				startDate: startDate
			)
			accountsManager.addRecurringTransaction(recurring)
		}
		dismiss()
	}
}

// MARK: - Preview

#Preview {
	AddRecurringTransactionView()
		.environment(AccountsManager.preview)
}
