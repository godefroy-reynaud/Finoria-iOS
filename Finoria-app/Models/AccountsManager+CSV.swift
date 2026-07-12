//
//  AccountsManager+CSV.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData

// MARK: - CSV (délégué à CSVService)
//
// Extension de domaine d'`AccountsManager` (voir AccountsManager.swift).
// Export (snapshot Sendable) et import des transactions du compte sélectionné.
extension AccountsManager {

	/// Snapshot Sendable des transactions du compte sélectionné pour la génération CSV.
	///
	/// Retourne `nil` s'il n'y a aucun compte ou aucune transaction à exporter.
	// WHY: les @Model SwiftData doivent être lus sur le main actor — ce snapshot
	// rapide en valeurs simples permet de générer le CSV hors du main actor
	// (Task.detached dans HomeTabView) sans bloquer l'UI.
	func csvExportSnapshot() -> (rows: [CSVService.ExportRow], accountName: String)? {
		guard let account = selectedAccount else { return nil }
		let rows = (account.transactions ?? [])
			.filter { !$0.potentiel && $0.sourceRecurringTransaction == nil }
			.map { transaction in
				CSVService.ExportRow(
					date: transaction.date,
					amount: transaction.amount,
					comment: transaction.comment,
					categoryLabel: transaction.displayCategoryLabel
				)
			}
		guard !rows.isEmpty else { return nil }
		return (rows, account.name)
	}

	/// Lit un fichier CSV et renvoie les transactions correspondantes,
	/// **sans rien enregistrer** (ni dans le store, ni dans iCloud).
	///
	/// On sépare la lecture de l'enregistrement pour pouvoir afficher à l'utilisateur
	/// le nombre de transactions trouvées et lui demander confirmation avant d'écrire
	/// (voir `HomeTabView`). L'enregistrement réel se fait ensuite via
	/// `commitImportedTransactions(_:)`.
	func parseCSVForImport(from url: URL) -> [Transaction] {
		CSVService.importCSV(from: url)
	}

	/// Enregistre dans le compte sélectionné des transactions déjà lues par
	/// `parseCSVForImport(from:)`, en résolvant/créant au passage leurs catégories
	/// personnalisées, puis persiste.
	/// - Returns: Le nombre de transactions effectivement ajoutées.
	func commitImportedTransactions(_ imported: [Transaction]) -> Int {
		guard let account = selectedAccount, !imported.isEmpty else { return 0 }

		// Index des catégories personnalisées du compte par nom normalisé.
		// Permet de retrouver une catégorie existante — ou créée pendant cet
		// import — sans jamais produire de doublon quand plusieurs lignes
		// partagent le même libellé de catégorie.
		var customCategoriesByName: [String: CustomTransactionCategory] = [:]
		for category in (account.customTransactionCategories ?? []) {
			customCategoriesByName[Self.normalizeCategoryName(category.name)] = category
		}

		for tx in imported {
			// WHY: une catégorie présente dans le CSV mais absente du compte est
			// désormais créée automatiquement (symbole et couleur par défaut,
			// personnalisables ensuite) afin que les transactions importées
			// partagent bien la même catégorie sans aucune action manuelle.
			if let importedName = tx.importedCategoryName,
				let customCategory = resolveCustomCategory(
					named: importedName,
					in: account,
					cache: &customCategoriesByName
				) {
				tx.customCategory = customCategory
				tx.category = .other
				tx.importedCategoryName = nil
			}
			tx.account = account
			modelContext.insert(tx)
		}
		persist()
		return imported.count
	}

	/// Retourne la catégorie personnalisée nommée `name` pour le compte, en la
	/// créant avec le symbole et la couleur par défaut si elle n'existe pas encore.
	/// Le cache évite les doublons et les recherches répétées sur un même import.
	// WHY: privée à ce fichier — seul `importCSV` ci-dessus l'utilise.
	private func resolveCustomCategory(
		named name: String,
		in account: Account,
		cache: inout [String: CustomTransactionCategory]
	) -> CustomTransactionCategory? {
		let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
		let key = Self.normalizeCategoryName(trimmedName)
		guard !key.isEmpty else { return nil }

		if let existing = cache[key] { return existing }

		let created = CustomTransactionCategory(name: trimmedName)
		created.account = account
		modelContext.insert(created)
		cache[key] = created
		return created
	}
}
