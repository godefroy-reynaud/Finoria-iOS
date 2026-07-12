//
//  Account.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/02/2026.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Style des comptes (icône + couleur liés)

enum AccountStyle: String, Codable, CaseIterable, Identifiable, StylableEnum {
	case bank           // Compte courant
	case savings        // Épargne
	case investment     // Investissements
	case business       // Professionnel
	case travel         // Voyage
	case grocery        // Courses / Quotidien
	case student        // Étudiant
	case family         // Famille
	case property       // Immobilier
	case entertainment  // Loisirs
	
	var id: String { rawValue }
	
	var icon: String {
		switch self {
		case .bank:          return "building.columns.fill"
		case .savings:       return "banknote.fill"
		case .investment:    return "chart.line.uptrend.xyaxis"
		case .business:      return "briefcase.fill"
		case .travel:        return "airplane"
		case .grocery:       return "cart.fill"
		case .student:       return "graduationcap.fill"
		case .family:        return "person.2.fill"
		case .property:      return "house.fill"
		case .entertainment: return "gamecontroller.fill"
		}
	}
	
	var color: Color {
		switch self {
		case .bank:          return .blue
		case .savings:       return .orange
		case .investment:    return .purple
		case .business:      return .indigo
		case .travel:        return .teal
		case .grocery:       return .green
		case .student:       return .cyan
		case .family:        return .pink
		case .property:      return .brown
		case .entertainment: return .red
		}
	}
	
	var label: String {
		switch self {
		case .bank:          return "Courant"
		case .savings:       return "Épargne"
		case .investment:    return "Investissement"
		case .business:      return "Professionnel"
		case .travel:        return "Voyage"
		case .grocery:       return "Courses"
		case .student:       return "Étudiant"
		case .family:        return "Famille"
		case .property:      return "Immobilier"
		case .entertainment: return "Loisirs"
		}
	}
	
	/// Devine le style par défaut selon le nom du compte
	static func guessFrom(name: String) -> AccountStyle {
		let text = name.lowercased()
		if text.contains("courant") || text.contains("principal") || text.contains("bnp") || text.contains("société générale") || text.contains("crédit") {
			return .bank
		} else if text.contains("livret") || text.contains("épargne") || text.contains("ldd") || text.contains("pel") {
			return .savings
		} else if text.contains("invest") || text.contains("pea") || text.contains("crypto") || text.contains("bourse") || text.contains("action") {
			return .investment
		} else if text.contains("pro") || text.contains("entreprise") || text.contains("business") {
			return .business
		} else if text.contains("voyage") || text.contains("vacance") || text.contains("trip") {
			return .travel
		} else if text.contains("course") || text.contains("quotidien") || text.contains("supermarché") {
			return .grocery
		} else if text.contains("étudiant") || text.contains("école") || text.contains("université") || text.contains("fac") {
			return .student
		} else if text.contains("famille") || text.contains("commun") || text.contains("joint") {
			return .family
		} else if text.contains("immo") || text.contains("maison") || text.contains("appart") || text.contains("loyer") {
			return .property
		} else if text.contains("loisir") || text.contains("jeu") || text.contains("divertissement") || text.contains("sorti") {
			return .entertainment
		}
		return .bank
	}
}

// MARK: - Modèle Account (SwiftData)

/// Modèle persistant représentant un compte financier.
///
/// Possède des relations one-to-many vers :
/// - `transactions` : toutes les transactions du compte
/// - `widgetShortcuts` : les raccourcis rapides
/// - `recurringTransactions` : les transactions récurrentes
///
/// La suppression d'un compte entraîne la suppression en cascade de toutes ses données liées.
///
/// ⚠️ ZÉRO PERTE DE DONNÉES : avant de modifier les propriétés/relations de ce modèle,
/// lisez la procédure de migration dans `FinoriaSchema.swift` (versionner le schéma +
/// ajouter une MigrationStage). Ne jamais renommer/supprimer un champ sans migration.
@Model
final class Account {
	
	// MARK: - Propriétés persistées
	
	var id: UUID = UUID()
	var name: String = ""
	var detail: String = ""
	var style: AccountStyle = AccountStyle.bank
	
	// MARK: - Relations (one-to-many, cascade delete)
	
	// WHY (optionnel) : CloudKit exige que TOUTE relation soit optionnelle
	// (« CloudKit integration requires that all relationships be optional »).
	// On garde `= []` comme valeur par défaut pour préserver la sémantique
	// (un nouveau compte a un tableau vide, pas nil) ; les lectures ailleurs
	// utilisent `?? []`. Changement ADDITIF → migration légère auto (cf. FinoriaSchema).
	@Relationship(deleteRule: .cascade, inverse: \Transaction.account)
	var transactions: [Transaction]? = []

	@Relationship(deleteRule: .cascade, inverse: \WidgetShortcut.account)
	var widgetShortcuts: [WidgetShortcut]? = []

	@Relationship(deleteRule: .cascade, inverse: \RecurringTransaction.account)
	var recurringTransactions: [RecurringTransaction]? = []

	@Relationship(deleteRule: .cascade, inverse: \CustomTransactionCategory.account)
	var customTransactionCategories: [CustomTransactionCategory]? = []
	
	// MARK: - Init
	
	init(id: UUID = UUID(), name: String, detail: String = "", style: AccountStyle? = nil) {
		self.id = id
		self.name = name
		self.detail = detail
		self.style = style ?? AccountStyle.guessFrom(name: name)
	}
}
