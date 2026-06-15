//
//  AccountsManager.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import Foundation
import SwiftData
import Observation
import os.log

/// Orchestrateur central de l'application.
///
/// **Règle d'or** : Toute modification de données DOIT passer par cette classe.
///
/// Responsabilités :
/// - Maintenir l'état observable pour SwiftUI
/// - Orchestrer les appels aux services spécialisés
/// - Garantir la persistance SwiftData après chaque mutation
///
/// Délègue à :
/// - `SwiftData ModelContext` pour la persistance
/// - `RecurrenceEngine` pour le traitement des récurrences
/// - `CalculationService` pour les calculs financiers
/// - `CSVService` pour l'import/export CSV
///
/// **Organisation du code** : pour alléger ce fichier, l'implémentation est
/// découpée par domaine dans des extensions du même module (un fichier par
/// responsabilité) :
/// - `AccountsManager+Accounts.swift` — CRUD comptes
/// - `AccountsManager+Transactions.swift` — CRUD transactions
/// - `AccountsManager+CustomCategories.swift` — catégories personnalisées
/// - `AccountsManager+Calculations.swift` — calculs & filtres (délégués)
/// - `AccountsManager+Shortcuts.swift` — raccourcis (widget shortcuts)
/// - `AccountsManager+CSV.swift` — import/export CSV
/// - `AccountsManager+Recurring.swift` — récurrences
///
/// Ce fichier ne conserve que l'état observé, le cycle de vie et les helpers
/// de persistance partagés par toutes les extensions.
// WHY: @MainActor garantit que toutes les mutations SwiftData et l'état observé
// se font sur le main thread (requis par ModelContext.mainContext et SwiftUI).
//
// WHY: @Observable (iOS 17) remplace ObservableObject : SwiftUI ne redessine que
// les vues qui lisent réellement la propriété modifiée, au lieu de redessiner
// toutes les vues abonnées à chaque changement de n'importe quelle @Published.
@MainActor
@Observable
class AccountsManager {

	// MARK: - Logger

	// WHY: interne (et non private) afin d'être utilisable via `Self.logger`
	// depuis les extensions de domaine (AccountsManager+*.swift) du même module.
	static let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "com.finoria",
		category: "AccountsManager"
	)

	// MARK: - Dependencies

	let modelContext: ModelContext

	// MARK: - État observé (Single Source of Truth)

	// WHY: Avec @Observable, plus besoin de @Published — toute propriété stockée
	// est automatiquement suivie, avec un tracking par propriété (plus fin).
	// WHY: Le tableau `accounts` en mémoire a été supprimé — les listes de comptes
	// sont lues par @Query directement dans les vues (lazy loading SwiftData).
	var selectedAccountId: UUID? {
		didSet { saveSelectedAccountId() }
	}

	/// Dernière erreur de persistance (pour affichage UI si nécessaire)
	var lastPersistenceError: String?

	/// Jeton de version des données — incrémenté après chaque mutation persistée.
	// WHY (FIX D): Depuis le retrait du tableau `accounts` re-fetché (qui rediffusait
	// tout à chaque persist), AUCUNE propriété observée du manager ne changeait quand
	// une transaction était ajoutée/modifiée/supprimée — et l'observation des relations
	// inverses SwiftData (account.transactions) ne déclenche pas le re-render de façon
	// fiable. Les helpers de lecture lisent ce jeton pendant l'évaluation du body :
	// chaque persist() l'incrémente, ce qui invalide toutes les vues concernées.
	// Chaîne restaurée : mutation → persist() → dataVersion+1 → @Observable → vue.
	private(set) var dataVersion: Int = 0

	/// Compte actuellement sélectionné (dérivé de selectedAccountId)
	// WHY: Fetch ciblé (fetchLimit = 1) au lieu d'une recherche dans le tableau
	// mémoire — SwiftData résout l'objet depuis son cache, pas de coût notable.
	var selectedAccount: Account? {
		// WHY (FIX D): enregistre la dépendance d'observation — tous les helpers
		// de lecture (transactions(), getWidgetShortcuts()…) passent par ici.
		_ = dataVersion
		guard let id = selectedAccountId else { return nil }
		var descriptor = FetchDescriptor<Account>(predicate: #Predicate { $0.id == id })
		descriptor.fetchLimit = 1
		return (try? modelContext.fetch(descriptor))?.first
	}

	// MARK: - Init

	init(modelContext: ModelContext) {
		self.modelContext = modelContext
		selectedAccountId = loadSelectedAccountId()
	}

	// MARK: - Preview Helper

	/// Crée un AccountsManager avec un conteneur en mémoire pour les Previews
	@MainActor
	static var preview: AccountsManager {
		do {
			let container = try SwiftDataService.makePreviewContainer()
			return AccountsManager(modelContext: container.mainContext)
		} catch {
			fatalError("Failed to create preview container: \(error)")
		}
	}

	// MARK: - Persistance interne

	/// Sauvegarde le contexte SwiftData.
	///
	/// CloudKit : `modelContext.save()` déclenche la synchronisation automatique.
	/// En cas de conflit, SwiftData utilise la politique de merge par défaut (server wins).
	/// Les erreurs sont loguées via os.log pour le diagnostic.
	// WHY: Plus de re-fetch manuel après chaque save — les vues @Query et les
	// @Model observés par SwiftUI se mettent à jour automatiquement.
	// WHY: interne (et non private) car appelée par toutes les extensions de
	// domaine (AccountsManager+*.swift) après chaque mutation.
	func persist() {
		do {
			try modelContext.save()
			lastPersistenceError = nil
		} catch {
			Self.logger.error("Échec sauvegarde SwiftData: \(error.localizedDescription)")
			lastPersistenceError = error.localizedDescription
		}
		// WHY (FIX D): signale la mutation aux vues (voir doc de dataVersion).
		dataVersion &+= 1
	}

	/// Premier compte (tri par nom), ou nil s'il n'en reste aucun
	// WHY: interne (et non private) car utilisée par l'extension +Accounts
	// (bascule de sélection après suppression) et par refreshFromStore.
	func firstAccount() -> Account? {
		var descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)])
		descriptor.fetchLimit = 1
		return (try? modelContext.fetch(descriptor))?.first
	}

	// MARK: - Persistance du compte sélectionné (UserDefaults — préférence UI)

	// WHY: Clé centralisée dans AppStorageKeys — une faute de frappe dans une
	// clé dupliquée serait un bug silencieux (sélection jamais restaurée).
	private func saveSelectedAccountId() {
		if let id = selectedAccountId {
			UserDefaults.standard.set(id.uuidString, forKey: AppStorageKeys.lastSelectedAccountId)
		} else {
			UserDefaults.standard.removeObject(forKey: AppStorageKeys.lastSelectedAccountId)
		}
	}

	private func loadSelectedAccountId() -> UUID? {
		guard let idString = UserDefaults.standard.string(forKey: AppStorageKeys.lastSelectedAccountId) else { return nil }
		return UUID(uuidString: idString)
	}

	// MARK: - Cycle de vie

	/// Sauvegarde publique pour besoins externes
	func saveData() {
		persist()
	}

	/// Valide la sélection au retour au premier plan (changements CloudKit).
	// WHY (FIX G): la condition couvre AUSSI le cas selectedAccountId == nil —
	// sur un second appareil, CloudKit livre les comptes APRÈS le .onAppear de
	// ContentView ; sans cela l'utilisateur restait sur un écran vide jusqu'à
	// ouverture manuelle du picker.
	func refreshFromStore() {
		Self.logger.info("Rafraîchissement depuis le store (CloudKit sync)")
		if selectedAccount == nil {
			selectedAccountId = firstAccount()?.id
		}
		// WHY (FIX D): les changements mergés depuis CloudKit doivent aussi
		// invalider les vues qui lisent via les helpers du manager.
		dataVersion &+= 1
	}

	// MARK: - Helpers partagés

	/// Normalisation canonique d'un nom de catégorie (trim + insensible casse/accents).
	// WHY (FIX J): implémentation unique — TransactionCategoryPicker utilisait
	// une copie identique, supprimée au profit de celle-ci.
	static func normalizeCategoryName(_ value: String) -> String {
		value
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
	}
}
