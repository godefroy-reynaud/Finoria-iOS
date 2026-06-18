//
//  RecurringTransaction.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 10/02/2026.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Fréquence de récurrence

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
	case daily    = "daily"
	case weekly   = "weekly"
	case monthly  = "monthly"
	case yearly   = "yearly"
	
	var id: String { rawValue }
	
	var label: String {
		switch self {
		case .daily:   return "Tous les jours"
		case .weekly:  return "Toutes les semaines"
		case .monthly: return "Tous les mois"
		case .yearly:  return "Tous les ans"
		}
	}
	
	var shortLabel: String {
		switch self {
		case .daily:   return "Quotidien"
		case .weekly:  return "Hebdo"
		case .monthly: return "Mensuel"
		case .yearly:  return "Annuel"
		}
	}
}

// MARK: - Modèle RecurringTransaction (SwiftData)

/// Modèle persistant représentant une transaction récurrente.
///
/// Génère automatiquement des `Transaction` potentielles pour le mois à venir.
/// Les transactions passées sont auto-validées par le `RecurrenceEngine`.
///
/// ⚠️ ZÉRO PERTE DE DONNÉES : avant de modifier les propriétés/relations de ce modèle,
/// lisez la procédure de migration dans `FinoriaSchema.swift` (versionner le schéma +
/// ajouter une MigrationStage). Ne jamais renommer/supprimer un champ sans migration.
@Model
final class RecurringTransaction {
	
	// MARK: - Propriétés persistées
	
	var id: UUID = UUID()
	var amount: Double = 0
	var comment: String = ""
	var type: TransactionType = TransactionType.expense
	var category: TransactionCategory = TransactionCategory.other
	var customCategory: CustomTransactionCategory?
	var frequency: RecurrenceFrequency = RecurrenceFrequency.monthly
	var startDate: Date = Date()
	/// Date de la dernière transaction générée (pour éviter les doublons)
	var lastGeneratedDate: Date?
	/// Indique si la récurrence est en pause (aucune transaction générée tant que c'est true)
	var isPaused: Bool = false
	
	// MARK: - Relations
	
	/// Compte propriétaire de cette récurrence
	var account: Account?
	
	/// Transactions générées par cette récurrence (nullify à la suppression)
	@Relationship(deleteRule: .nullify, inverse: \Transaction.sourceRecurringTransaction)
	var generatedTransactions: [Transaction] = []
	
	// MARK: - Init
	
	init(
		id: UUID = UUID(),
		amount: Double,
		comment: String,
		type: TransactionType,
		category: TransactionCategory? = nil,
		customCategory: CustomTransactionCategory? = nil,
		frequency: RecurrenceFrequency = .monthly,
		startDate: Date = Date(),
		lastGeneratedDate: Date? = nil,
		isPaused: Bool = false
	) {
		self.id = id
		self.amount = amount
		self.comment = comment
		self.type = type
		self.customCategory = customCategory
		if customCategory != nil {
			self.category = .other
		} else {
			self.category = category ?? TransactionCategory.guessFrom(comment: comment, type: type)
		}
		self.frequency = frequency
		self.startDate = startDate
		self.lastGeneratedDate = lastGeneratedDate
		self.isPaused = isPaused
	}
	
	// MARK: - Calcul des prochaines occurrences
	
	/// Retourne toutes les dates d'occurrence entre deux dates
	// WHY (FIX A): Chaque occurrence est calculée depuis la date d'ancrage (startDate),
	// jamais en chaînant depuis l'occurrence précédente. Sinon le clamping de
	// Calendar s'accumule : un loyer du 31 janvier devient 28 février (clampé),
	// puis dérive définitivement au 28 mars, 28 avril… Avec l'ancrage, on obtient
	// 31 janv → 28 févr → 31 mars → 30 avr → 31 mai (comportement attendu).
	func occurrences(from startRange: Date, to endRange: Date) -> [Date] {
		let calendar = Calendar.current
		var dates: [Date] = []
		var occurrenceIndex = 0

		while let date = occurrenceDate(at: occurrenceIndex, calendar: calendar) {
			if date > endRange { break }
			if date >= startRange {
				dates.append(date)
			}
			occurrenceIndex += 1
		}

		return dates
	}

	/// Date de la n-ième occurrence (0 = startDate), toujours calculée depuis l'ancrage
	private func occurrenceDate(at index: Int, calendar: Calendar) -> Date? {
		switch frequency {
		case .daily:
			return calendar.date(byAdding: .day, value: index, to: startDate)
		case .weekly:
			return calendar.date(byAdding: .weekOfYear, value: index, to: startDate)
		case .monthly:
			return calendar.date(byAdding: .month, value: index, to: startDate)
		case .yearly:
			return calendar.date(byAdding: .year, value: index, to: startDate)
		}
	}
	
	/// Retourne les transactions potentielles à générer (occurrences dans le mois à venir non encore générées)
	func pendingTransactions() -> [(date: Date, transaction: Transaction)] {
		let calendar = Calendar.current
		let now = Date()
		let startOfToday = calendar.startOfDay(for: now)
		
		guard let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: startOfToday) else {
			return []
		}
		
		let upcoming = occurrences(from: startOfToday, to: oneMonthLater)
		
		return upcoming
			.filter { date in
				// Ne pas regénérer si déjà généré pour cette date
				if let lastGenerated = lastGeneratedDate {
					return date > lastGenerated
				}
				return true
			}
			.map { date in
				let finalAmount = type == .income ? amount : -amount
				let isToday = calendar.isDate(date, inSameDayAs: now)
				// Les transactions du jour sont directement validées
				// Les futures sont potentielles avec une date prévue (pour auto-validation ultérieure)
				let transaction = Transaction(
					amount: finalAmount,
					comment: comment,
					potentiel: !isToday,
					date: date,
					category: category,
					sourceRecurringTransaction: self,
					customCategory: customCategory
				)
				return (date: date, transaction: transaction)
			}
	}

	var displayCategoryIcon: String {
		customCategory?.symbol ?? category.icon
	}

	var displayCategoryColor: Color {
		customCategory?.resolvedColor ?? category.color
	}
}
