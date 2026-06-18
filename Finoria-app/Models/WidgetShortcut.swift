//
//  WidgetShortcut.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 08/08/2025.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Modèle WidgetShortcut (SwiftData)

/// Modèle persistant représentant un raccourci rapide pour ajouter une transaction en un tap.
///
/// ⚠️ ZÉRO PERTE DE DONNÉES : avant de modifier les propriétés/relations de ce modèle,
/// lisez la procédure de migration dans `FinoriaSchema.swift` (versionner le schéma +
/// ajouter une MigrationStage). Ne jamais renommer/supprimer un champ sans migration.
@Model
final class WidgetShortcut {
	
	// MARK: - Propriétés persistées
	
	var id: UUID = UUID()
	var amount: Double = 0
	var comment: String = ""
	var type: TransactionType = TransactionType.expense
	var category: TransactionCategory = TransactionCategory.other
	var customCategory: CustomTransactionCategory?
	
	// MARK: - Relations
	
	/// Compte propriétaire de ce raccourci
	var account: Account?
	
	// MARK: - Init
	
	init(
		id: UUID = UUID(),
		amount: Double,
		comment: String,
		type: TransactionType,
		category: TransactionCategory? = nil,
		customCategory: CustomTransactionCategory? = nil
	) {
		self.id = id
		self.amount = amount
		self.comment = comment
		self.type = type
		self.customCategory = customCategory
		if customCategory != nil {
			self.category = .other
		} else {
			// Si pas de catégorie fournie, on la devine automatiquement
			self.category = category ?? TransactionCategory.guessFrom(comment: comment, type: type)
		}
	}

	var displayCategoryIcon: String {
		customCategory?.symbol ?? category.icon
	}

	var displayCategoryColor: Color {
		customCategory?.resolvedColor ?? category.color
	}
}
