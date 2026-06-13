//
//  AnalysesModels.swift
//  Finoria
//

import SwiftUI

// MARK: - Modèle de données pour le graphique

/// Représente une catégorie (intégrée ou personnalisée) avec son montant total
/// et son nombre de transactions.
///
/// L'affichage (libellé, icône, couleur) est délégué à une transaction
/// représentative via `displayCategory*` : on réutilise ainsi la même logique de
/// catégorie que partout ailleurs dans l'app, sans la dupliquer.
struct CategoryData: Identifiable {
	let representative: Transaction
	let total: Double
	let count: Int

	/// Identité du regroupement : la catégorie personnalisée prime, sinon la catégorie intégrée.
	static func groupKey(for transaction: Transaction) -> String {
		transaction.customCategory?.id.uuidString ?? "builtin-\(transaction.category.rawValue)"
	}

	var id: String { Self.groupKey(for: representative) }

	var label: String { representative.displayCategoryLabel }
	var icon: String { representative.displayCategoryIcon }
	var color: Color { representative.displayCategoryColor }

	var category: TransactionCategory { representative.category }
	var customCategoryId: UUID? { representative.customCategory?.id }
}

// MARK: - Type d'analyse

/// Dépenses ou Revenus — utilisé par le Picker segmenté dans AnalysesView
enum AnalysisType: String, CaseIterable {
	case expenses = "Dépenses"
	case income = "Revenus"
}

// MARK: - Route de navigation

/// Route Hashable vers le détail des transactions d'une catégorie pour un mois donné.
/// La catégorie est identifiée par le même couple que partout dans l'app :
/// catégorie intégrée + identifiant de catégorie personnalisée éventuel.
struct CategoryDetailRoute: Hashable {
	let category: TransactionCategory
	let customCategoryId: UUID?
	let month: Int
	let year: Int
}

// MARK: - Icône de catégorie

/// Affiche une icône dans un cercle coloré à partir d'un symbole et d'une couleur.
/// Factorise le motif déjà répété ailleurs (TransactionRow, raccourcis…) et permet
/// d'afficher aussi bien les catégories intégrées que personnalisées.
struct CategoryIconView: View {
	let icon: String
	let color: Color
	var size: CGFloat = 40

	var body: some View {
		ZStack {
			Circle()
				.fill(color.opacity(0.15))
				.frame(width: size, height: size)
			Image(systemName: icon)
				.font(.system(size: size * 0.45))
				.foregroundStyle(color)
		}
	}
}
