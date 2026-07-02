//
//  AccountsManager+Accounts.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData

// MARK: - Gestion des comptes
//
// Extension de domaine d'`AccountsManager` (voir AccountsManager.swift).
// CRUD des comptes ; la suppression cascade vers tout ce que le compte possède.
extension AccountsManager {

	func addAccount(_ account: Account) {
		modelContext.insert(account)
		persist()
	}

	func deleteAccount(_ account: Account) {
		let wasSelected = selectedAccountId == account.id
		modelContext.delete(account) // cascade : supprime transactions, raccourcis, récurrences
		persist()

		// WHY: Re-fetch du premier compte restant (plus de tableau en mémoire)
		// pour basculer la sélection ou la vider s'il n'y a plus de compte.
		let remaining = firstAccount()
		if remaining == nil {
			selectedAccountId = nil
		} else if wasSelected {
			selectedAccountId = remaining?.id
		}
	}

	func updateAccount(_ account: Account, name: String, detail: String, style: AccountStyle) {
		account.name = name
		account.detail = detail
		account.style = style
		persist()
	}

	func resetAccount(_ account: Account) {
		for transaction in account.transactions {
			modelContext.delete(transaction)
		}
		// WHY: On vient de supprimer toutes les transactions (dont les futures
		// générées par les récurrences). On met les récurrences en pause pour
		// éviter qu'elles ne regénèrent des transactions ; l'utilisateur les
		// réactivera manuellement si besoin.
		for recurring in account.recurringTransactions {
			recurring.isPaused = true
		}
		persist()
	}
}
