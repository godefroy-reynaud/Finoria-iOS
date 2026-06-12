//
//  AccountPickerView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 07/08/2025.
//

import SwiftUI
import SwiftData

struct AccountPickerView: View {
	@Environment(\.dismiss) var dismiss
	@Environment(AccountsManager.self) private var accountsManager

	// WHY: @Query lit les comptes directement depuis SwiftData (lazy loading,
	// mise à jour automatique y compris après une sync CloudKit) — remplace
	// le tableau en mémoire que AccountsManager rechargeait manuellement.
	@Query(sort: \Account.name) private var accounts: [Account]

	@State private var showingAddAccount = false
	@State private var accountToEdit: Account? = nil
	@State private var accountToReset: Account? = nil
	@State private var showingResetConfirmation = false
	
	var body: some View {
		NavigationStack {
				List {
					ForEach(accounts) { account in
						AccountCardView(
							account: account,
							solde: accountsManager.totalNonPotential(for: account),
							futur: accountsManager.totalNonPotential(for: account) + accountsManager.totalPotential(for: account)
						)
						.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
						.listRowBackground(Color.clear)
						.listRowSeparator(.hidden)
						.contentShape(Rectangle())
						.onTapGesture {
							accountsManager.selectedAccountId = account.id
							dismiss()
						}
						.contextMenu {
							Button {
								accountToEdit = account
							} label: {
								Label("Modifier", systemImage: "pencil")
							}
							
							Button(role: .destructive) {
								accountToReset = account
								showingResetConfirmation = true
							} label: {
								Label("Réinitialiser", systemImage: "arrow.counterclockwise")
							}
							
							Button(role: .destructive) {
								accountsManager.deleteAccount(account)
							} label: {
								Label("Supprimer", systemImage: "trash")
							}
						}
						.swipeActions(edge: .trailing, allowsFullSwipe: true) {
							Button(role: .destructive) {
								accountsManager.deleteAccount(account)
							} label: {
								Label("Supprimer", systemImage: "trash")
							}
						}
					}
				
				// Bouton Ajouter
				Button {
					showingAddAccount = true
				} label: {
					HStack {
						Image(systemName: "plus.circle.fill")
							.font(.title2)
						Text("Ajouter un compte")
							.font(.headline)
					}
					.foregroundStyle(.blue)
					.frame(maxWidth: .infinity)
					.padding(.vertical, 20)
					.background(Color(.systemBackground))
					.clipShape(RoundedRectangle(cornerRadius: 20))
					.shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
				}
				.buttonStyle(PlainButtonStyle())
				.listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
				.listRowBackground(Color.clear)
				.listRowSeparator(.hidden)
			}
			.listStyle(.plain)
			.scrollContentBackground(.hidden)
			.adaptiveGroupedBackground()
			.navigationTitle("Mes comptes")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Fermer") {
						dismiss()
					}
				}
			}
			.sheet(isPresented: $showingAddAccount) {
				AddAccountSheet {
					dismiss()
				}
			}
			.sheet(item: $accountToEdit) { account in
				AddAccountSheet(accountToEdit: account)
			}
			.alert("Réinitialiser ce compte ?", isPresented: $showingResetConfirmation) {
				Button("Réinitialiser", role: .destructive) {
					if let account = accountToReset {
						accountsManager.resetAccount(account)
					}
				}
				Button("Annuler", role: .cancel) { }
			} message: {
				Text("Toutes les transactions de ce compte seront supprimées. Les raccourcis, transactions récurrentes et catégories personnalisées seront conservés. Cette action est irréversible.")
			}
		}
	}
}
