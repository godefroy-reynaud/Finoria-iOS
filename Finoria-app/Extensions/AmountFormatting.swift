//
//  AmountFormatting.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import Foundation

// MARK: - Formatage compact des montants

/// Formate un montant de manière compacte pour tenir dans un espace restreint.
/// Utilise la locale du système (virgule pour les français, point pour les anglophones, etc.)
/// Réduit progressivement la précision : 2 850,00 € → 2 850 € → 2,85k € → 2,9k € → 3k €
func compactAmount(_ value: Double) -> String {
	let formatter = NumberFormatter()
	formatter.locale = Locale.current
	formatter.numberStyle = .decimal
	formatter.usesGroupingSeparator = false

	let thresholds: [(limit: Double, divisor: Double, suffix: String)] = [
		(1_000_000_000, 1_000_000_000, "G"),
		(1_000_000, 1_000_000, "M"),
		(1_000, 1_000, "k")
	]

	for t in thresholds where value >= t.limit {
		let reduced = value / t.divisor
		if reduced == reduced.rounded(.down) {
			formatter.minimumFractionDigits = 0
			formatter.maximumFractionDigits = 0
		} else if (reduced * 10).rounded() == (reduced * 10) {
			formatter.minimumFractionDigits = 1
			formatter.maximumFractionDigits = 1
		} else {
			formatter.minimumFractionDigits = 2
			formatter.maximumFractionDigits = 2
		}
		return "\(formatter.string(from: NSNumber(value: reduced)) ?? "\(reduced)")\(t.suffix)"
	}

	if value == value.rounded(.down) {
		formatter.minimumFractionDigits = 0
		formatter.maximumFractionDigits = 0
	} else if (value * 10).rounded() == (value * 10) {
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 1
	} else {
		formatter.minimumFractionDigits = 2
		formatter.maximumFractionDigits = 2
	}
	return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}
