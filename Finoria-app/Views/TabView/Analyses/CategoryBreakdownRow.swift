//
//  CategoryBreakdownRow.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 12/02/2026.
//

import SwiftUI

/// Ligne détaillée affichant une catégorie avec son montant, pourcentage et nombre de transactions
struct CategoryBreakdownRow: View {
	let item: CategoryData
	let totalAmount: Double
	var isSelected: Bool = false
	
	/// Pourcentage de cette catégorie par rapport au total
	private var percentage: Double {
		guard totalAmount > 0 else { return 0 }
		return (item.total / totalAmount) * 100
	}
	
	var body: some View {
		HStack(spacing: 12) {
			// Icône de la catégorie
			CategoryIconView(icon: item.icon, color: item.color, size: 40)

			// Nom de la catégorie + nombre de transactions
			VStack(alignment: .leading, spacing: 2) {
				Text(item.label)
					.font(.subheadline.weight(.medium))
				Text("\(item.count) transaction\(item.count > 1 ? "s" : "")")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer()
			
			// Montant + pourcentage
			VStack(alignment: .trailing, spacing: 2) {
				Text(item.total, format: .currency(code: "EUR"))
					.font(.subheadline.weight(.semibold))
				Text(String(format: "%.1f%%", percentage))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}
}
