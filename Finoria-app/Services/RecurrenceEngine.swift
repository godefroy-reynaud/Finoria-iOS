//
//  RecurrenceEngine.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 12/02/2026.
//

import Foundation
import SwiftData

/// Moteur de traitement des transactions récurrentes.
///
/// Responsabilités :
/// - Générer les transactions potentielles à venir (< 1 mois)
/// - Auto-valider les transactions dont la date est passée
/// - Nettoyer les transactions potentielles lors de suppression/modification de récurrence
///
/// Ce service utilise le `ModelContext` pour insérer/supprimer des objets SwiftData.
/// C'est `AccountsManager` qui persiste (save) après chaque appel.
struct RecurrenceEngine {
	
	// MARK: - Traitement global
	
	/// Traite toutes les récurrences de tous les comptes.
	/// Génère les transactions futures et valide automatiquement celles dont la date est passée.
	///
	/// - Parameters:
	///   - accounts: Liste de tous les comptes
	///   - context: Le ModelContext SwiftData pour insérer les nouvelles transactions
	/// - Returns: `true` si des modifications ont été effectuées
	@discardableResult
	static func processAll(
		accounts: [Account],
		context: ModelContext
	) -> Bool {
		let calendar = Calendar.current
		let now = Date()
		let startOfToday = calendar.startOfDay(for: now)
		var anyChange = false
		
		for account in accounts {
			
			// 1. Générer les transactions potentielles depuis les récurrences actives
			for recurring in account.recurringTransactions where !recurring.isPaused {
				let pending = recurring.pendingTransactions()
				
				for entry in pending {
					let alreadyExists = account.transactions.contains { tx in
						// WHY: Replaced force unwrap (!) with optional binding via if-let to prevent crashes.
						// Safely unwraps tx.date before date comparison.
						if let txDate = tx.date {
							return tx.sourceRecurringTransaction?.id == recurring.id &&
							calendar.isDate(txDate, inSameDayAs: entry.date)
						}
						return false
					}
					if !alreadyExists {
						let transaction = entry.transaction
						transaction.account = account
						context.insert(transaction)
						anyChange = true
					}
				}
				
				// Mettre à jour la dernière date générée
				if let lastDate = pending.map({ $0.date }).max() {
					recurring.lastGeneratedDate = lastDate
				}
			}
			
			// 2. Auto-valider les transactions potentielles dont la date prévue est passée
			for transaction in account.transactions where transaction.potentiel {
				if let date = transaction.date, calendar.startOfDay(for: date) <= startOfToday {
					transaction.validate(at: date)
					anyChange = true
				}
			}
		}
		
		return anyChange
	}
	
	// MARK: - Nettoyage
	
	/// Supprime toutes les transactions potentielles liées à une récurrence donnée.
	/// Utilisé lors de la suppression, modification ou mise en pause d'une récurrence.
	///
	/// - Parameters:
	///   - recurring: La récurrence dont les transactions potentielles doivent être supprimées
	///   - context: Le ModelContext pour supprimer les objets
	static func removePotentialTransactions(for recurring: RecurringTransaction, context: ModelContext) {
		let potentials = recurring.generatedTransactions.filter { $0.potentiel }
		for transaction in potentials {
			context.delete(transaction)
		}
	}
}
