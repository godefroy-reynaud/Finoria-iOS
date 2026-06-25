//
//  CustomTransactionCategory.swift
//  Finoria
//
//  Created by GitHub Copilot on 16/03/2026.
//

import Foundation
import SwiftData
import SwiftUI

/// Catégorie personnalisée créée localement pour un compte.
///
/// ⚠️ ZÉRO PERTE DE DONNÉES : avant de modifier les propriétés/relations de ce modèle,
/// lisez la procédure de migration dans `FinoriaSchema.swift` (versionner le schéma +
/// ajouter une MigrationStage). Ne jamais renommer/supprimer un champ sans migration.
@Model
final class CustomTransactionCategory {
	var id: UUID = UUID()
	var name: String = ""
	var symbol: String = "tag.fill"
	var colorHex: String = "#8E8E93"

	/// Compte propriétaire de la catégorie personnalisée.
	var account: Account?

	/// Transactions rattachées à cette catégorie personnalisée.
	@Relationship(deleteRule: .nullify, inverse: \Transaction.customCategory)
	var transactions: [Transaction] = []

	// WHY (inverses explicites) : `WidgetShortcut.customCategory` et
	// `RecurringTransaction.customCategory` reposaient sur un inverse synthétisé
	// implicitement par SwiftData. On le déclare désormais explicitement pour que
	// le comportement de suppression (nullify) soit garanti et lisible : supprimer
	// une catégorie perso met `customCategory = nil` sur les raccourcis/récurrences
	// qui la référençaient, au lieu de laisser une référence dépendant de l'inférence.
	// ⚠️ Changement de structure → schéma versionné V2 (voir FinoriaSchema.swift).

	/// Raccourcis utilisant cette catégorie personnalisée.
	@Relationship(deleteRule: .nullify, inverse: \WidgetShortcut.customCategory)
	var widgetShortcuts: [WidgetShortcut] = []

	/// Récurrences utilisant cette catégorie personnalisée.
	@Relationship(deleteRule: .nullify, inverse: \RecurringTransaction.customCategory)
	var recurringTransactions: [RecurringTransaction] = []

	init(
		id: UUID = UUID(),
		name: String,
		symbol: String = "tag.fill",
		colorHex: String = "#8E8E93"
	) {
		self.id = id
		self.name = name
		self.symbol = symbol
		self.colorHex = colorHex
	}

	var resolvedColor: Color {
		Color(finoriaHex: colorHex)
	}
}
