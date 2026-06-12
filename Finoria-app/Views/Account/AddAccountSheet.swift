//
//  AddAccountSheet.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/02/2026.
//

import SwiftUI

struct AddAccountSheet: View {
	@Environment(\.dismiss) var dismiss
	@Environment(AccountsManager.self) private var accountsManager
	var onAccountCreated: (() -> Void)?

	// Compte à éditer (nil = nouveau compte)
	var accountToEdit: Account? = nil

	// MARK: - Limites
	private let maxNameLength = 15
	private let maxDetailLength = 20

	@State private var name = ""
	@State private var detail = ""
	@State private var style: AccountStyle = .bank
	@State private var hasManuallySelectedStyle = false

	private var isEditMode: Bool { accountToEdit != nil }

	init(accountToEdit: Account? = nil, onAccountCreated: (() -> Void)? = nil) {
		self.accountToEdit = accountToEdit
		self.onAccountCreated = onAccountCreated
	}
	
	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Nom du compte", text: $name)
						.onChange(of: name) { _, newValue in
							if newValue.count > maxNameLength {
								name = String(newValue.prefix(maxNameLength))
							}
							// Ne pas auto-deviner le style si mode édition ou sélection manuelle
							if !isEditMode && !hasManuallySelectedStyle {
								style = AccountStyle.guessFrom(name: newValue)
							}
						}
					TextField("Détail (optionnel)", text: $detail)
						.onChange(of: detail) { _, newValue in
							if newValue.count > maxDetailLength {
								detail = String(newValue.prefix(maxDetailLength))
							}
						}
				} header: {
					Text("Informations")
				} footer: {
					HStack {
						Text("\(name.count)/\(maxNameLength)")
						Spacer()
						Text("\(detail.count)/\(maxDetailLength)")
					}
				}
				
				Section("Icône") {
					AccountCategoryPicker(selectedStyle: $style, columns: 5) {
						hasManuallySelectedStyle = true
					}
				}
				
				// Aperçu
				Section("Aperçu") {
					AccountCardView(
						account: Account(name: name.isEmpty ? "Nouveau compte" : name, detail: detail, style: style),
						solde: 0,
						futur: 0
					)
					.listRowInsets(EdgeInsets())
					.listRowBackground(Color.clear)
				}
				
				// Bouton supprimer en mode édition
				if isEditMode {
					Section {
						Button(role: .destructive) {
							if let account = accountToEdit {
								accountsManager.deleteAccount(account)
								dismiss()
							}
						} label: {
							HStack {
								Spacer()
								Label("Supprimer le compte", systemImage: "trash")
								Spacer()
							}
						}
					}
				}
			}
			.scrollContentBackground(.hidden)
			.adaptiveGroupedBackground()
			.navigationTitle(isEditMode ? "Modifier le compte" : "Nouveau compte")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Annuler") {
						dismiss()
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isEditMode ? "OK" : "Créer") {
						saveAccount()
					}
					.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
			}
			.onAppear {
				if let account = accountToEdit {
					name = account.name
					detail = account.detail
					style = account.style
				}
			}
		}
	}
	
	private func saveAccount() {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		
		if let existingAccount = accountToEdit {
			// Mode édition: mutation en place de l'objet SwiftData
			accountsManager.updateAccount(
				existingAccount,
				name: trimmed,
				detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
				style: style
			)
		} else {
			// Mode création: nouveau compte
			let account = Account(name: trimmed, detail: detail, style: style)
			accountsManager.addAccount(account)
			accountsManager.selectedAccountId = account.id
			onAccountCreated?()
		}
		dismiss()
	}
}
