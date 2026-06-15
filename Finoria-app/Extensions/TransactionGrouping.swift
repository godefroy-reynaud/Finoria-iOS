//
//  TransactionGrouping.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 15/06/2026.
//

import Foundation

// MARK: - Regroupement de transactions par jour

extension Array where Element == Transaction {
	/// Regroupe les transactions par jour (minuit local), du jour le plus récent
	/// au plus ancien. Les transactions sans date sont regroupées sous
	/// `Date.distantPast`.
	///
	/// L'ordre **au sein** de chaque jour est celui du tableau source
	/// (`Dictionary(grouping:)` préserve l'ordre d'insertion) : triez le tableau
	/// avant d'appeler ce helper si un ordre intra-jour précis est requis
	/// (les appelants passent une liste déjà triée par date décroissante).
	func groupedByDay() -> [(date: Date, transactions: [Transaction])] {
		let calendar = Calendar.current
		let grouped = Dictionary(grouping: self) { transaction -> Date in
			guard let date = transaction.date else { return Date.distantPast }
			return calendar.startOfDay(for: date)
		}
		return grouped.sorted { $0.key > $1.key }
			.map { (date: $0.key, transactions: $0.value) }
	}
}
