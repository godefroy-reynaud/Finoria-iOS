//
//  AddWidgetShortcutView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 08/08/2025.
//

import SwiftUI

struct AddWidgetShortcutView: View {
	@Environment(\.dismiss) var dismiss
	@Environment(AccountsManager.self) private var accountsManager
	
	// Raccourci à éditer (nil = nouveau raccourci)
	var shortcutToEdit: WidgetShortcut? = nil
	
	// MARK: - Limites
	private let maxCommentLength = 15
	
	@State private var amount: Double?
	@State private var comment = ""
	@State private var type: TransactionType = .income
	@State private var selectedCategory: TransactionCategory = .income
	@State private var selectedCustomCategoryId: UUID?
	@State private var showError = false
	@State private var errorMessage = ""
	@State private var hasManuallySelectedCategory = false
	
	private var isEditMode: Bool { shortcutToEdit != nil }
	
	var body: some View {
		NavigationStack {
			Form {
				Section {
					CurrencyTextField("Montant", amount: $amount)

					TextField("Commentaire", text: $comment)
						.onChange(of: comment) { _, newValue in
							if newValue.count > maxCommentLength {
								comment = String(newValue.prefix(maxCommentLength))
							}
							// Ne pas auto-deviner la catégorie si mode édition ou sélection manuelle
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
				
				Picker("Type", selection: $type) {
					ForEach(TransactionType.allCases) { t in
						Text(t.label).tag(t)
					}
				}
				.pickerStyle(.segmented)
				.onChange(of: type) { _, newValue in
					// Met à jour la catégorie si c'est la catégorie par défaut (seulement si pas en mode édition et pas de sélection manuelle)
					if !isEditMode && !hasManuallySelectedCategory && selectedCustomCategoryId == nil && (selectedCategory == .income || selectedCategory == .expense) {
						selectedCategory = newValue == .income ? .income : .expense
					}
				}
				
				// MARK: - Sélecteur de catégorie
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
							if let shortcut = shortcutToEdit {
								accountsManager.deleteWidgetShortcut(shortcut)
								dismiss()
							}
						} label: {
							HStack {
								Spacer()
								Label("Supprimer le raccourci", systemImage: "trash")
								Spacer()
							}
						}
					}
				}
			}
			.navigationTitle(isEditMode ? "Modifier le raccourci" : "Nouveau raccourci")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Annuler") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isEditMode ? "OK" : "Ajouter") {
						saveShortcut()
					}
				}
			}
			.alert("Erreur", isPresented: $showError) {
				Button("OK", role: .cancel) {}
			} message: {
				Text(errorMessage)
			}
			.onAppear {
				if let shortcut = shortcutToEdit {
					amount = shortcut.amount
					comment = shortcut.comment
					type = shortcut.type
					if let customCategory = shortcut.customCategory {
						selectedCategory = .other
						selectedCustomCategoryId = customCategory.id
					} else {
						selectedCategory = shortcut.category
						selectedCustomCategoryId = nil
					}
				}
			}
		}
	}
	
	private func saveShortcut() {
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

		if let existingShortcut = shortcutToEdit {
			// Mode édition: mutation en place de l'objet SwiftData
			accountsManager.updateWidgetShortcut(
				existingShortcut,
				amount: amount,
				comment: comment,
				type: type,
				category: builtInCategory,
				customCategory: customCategory
			)
		} else {
			// Mode création: nouveau raccourci
			let shortcut = WidgetShortcut(
				amount: amount,
				comment: comment,
				type: type,
				category: builtInCategory,
				customCategory: customCategory
			)
			accountsManager.addWidgetShortcut(shortcut)
		}
		dismiss()
	}
}
