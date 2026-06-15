//
//  AccountsManager+Calculations.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation

// MARK: - Calculs & filtres (délégués à CalculationService)
//
// Extension de domaine d'`AccountsManager` (voir AccountsManager.swift).
// Lecture seule : aucune mutation, simple délégation au service de calcul pur.
extension AccountsManager {

	// MARK: - Calculs

	func totalNonPotential(for account: Account) -> Double {
		// WHY (FIX D): ces deux helpers reçoivent un compte externe (@Query du
		// picker) sans passer par selectedAccount — dépendance enregistrée ici.
		_ = dataVersion
		return CalculationService.totalNonPotential(transactions: account.transactions)
	}

	func totalPotential(for account: Account) -> Double {
		_ = dataVersion
		return CalculationService.totalPotential(transactions: account.transactions)
	}

	func availableYears() -> [Int] {
		CalculationService.availableYears(transactions: transactions())
	}

	func totalForYear(_ year: Int) -> Double {
		CalculationService.totalForYear(year, transactions: transactions())
	}

	func totalForMonth(_ month: Int, year: Int) -> Double {
		CalculationService.totalForMonth(month, year: year, transactions: transactions())
	}

	func monthlyChangePercentage() -> Double? {
		CalculationService.monthlyChangePercentage(transactions: transactions())
	}

	// MARK: - Filtres

	func potentialTransactions() -> [Transaction] {
		CalculationService.potentialTransactions(from: transactions())
	}

	func validatedTransactions(year: Int? = nil, month: Int? = nil) -> [Transaction] {
		CalculationService.validatedTransactions(from: transactions(), year: year, month: month)
	}
}
