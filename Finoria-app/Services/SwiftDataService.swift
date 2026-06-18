//
//  SwiftDataService.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/03/2026.
//

import Foundation
import SwiftData

/// Configuration du conteneur SwiftData pour Finoria.
///
/// Responsabilités :
/// - Créer et configurer le `ModelContainer` avec le schéma courant
/// - Synchroniser les données via CloudKit (iCloud)
/// - Fournir un conteneur en mémoire pour les Previews et tests
///
/// ## Synchronisation CloudKit (ACTIVÉE)
/// CloudKit est activé avec `cloudKitDatabase: .automatic`.
/// Les données sont synchronisées automatiquement entre les appareils du même compte iCloud.
///
/// Prérequis Xcode :
/// - Capability "iCloud" avec CloudKit coché + container `iCloud.com.godefroyinformatique.GDF-app`
/// - Capability "Push Notifications" activée
/// - Capability "Background Modes" → "Remote notifications" coché
/// - Aucun `@Attribute(.unique)` sur les modèles (incompatible CloudKit)
///
/// ## ⚠️ ÉVOLUTION DE LA STRUCTURE DE DONNÉES — ZÉRO PERTE
/// Le schéma est VERSIONNÉ (`FinoriaSchemaV1`) et un plan de migration
/// (`FinoriaMigrationPlan`) est passé à CHAQUE conteneur ci-dessous. C'est ce qui
/// garantit qu'aucune donnée utilisateur n'est perdue lors d'une mise à jour qui
/// change la structure. **Avant de modifier un `@Model`, lisez `FinoriaSchema.swift`
/// et suivez la procédure de migration qui y est documentée.**
enum SwiftDataService {

	// MARK: - Schema

	/// Liste des modèles SwiftData de l'application.
	/// Source de vérité : la version courante du schéma (voir `FinoriaSchema.swift`).
	static var models: [any PersistentModel.Type] {
		FinoriaCurrentSchema.models
	}

	/// Schéma versionné courant, partagé par toutes les fabriques de conteneur.
	/// Construit à partir de `FinoriaCurrentSchema` pour que la version (et donc
	/// le plan de migration) soit toujours prise en compte.
	private static var currentSchema: Schema {
		Schema(versionedSchema: FinoriaCurrentSchema.self)
	}

	// MARK: - Production Container (CloudKit activé)

	/// Crée le `ModelContainer` configuré pour l'application en production avec CloudKit.
	///
	/// Les données sont persistées sur disque et synchronisées via iCloud.
	/// Le `migrationPlan` garantit que toute évolution de structure (versions
	/// successives du schéma) migre les données existantes au lieu de les perdre.
	static func makeContainer() throws -> ModelContainer {
		let schema = currentSchema
		let configuration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: false,
			allowsSave: true,
			cloudKitDatabase: .automatic
		)

		return try ModelContainer(
			for: schema,
			migrationPlan: FinoriaMigrationPlan.self,
			configurations: configuration
		)
	}

	// MARK: - Fallback Container (CloudKit désactivé, données SUR DISQUE)

	/// Crée un `ModelContainer` **sur disque** mais sans CloudKit.
	///
	/// Utilisé comme fallback si CloudKit échoue (pas de compte iCloud, simulateur, etc.).
	/// **Les données sont persistées** — rien n'est perdu au redémarrage.
	/// Le même `migrationPlan` est appliqué pour ne perdre aucune donnée locale
	/// lors d'un changement de structure.
	static func makeFallbackContainer() throws -> ModelContainer {
		let schema = currentSchema
		let configuration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: false,
			allowsSave: true,
			cloudKitDatabase: .none
		)

		return try ModelContainer(
			for: schema,
			migrationPlan: FinoriaMigrationPlan.self,
			configurations: configuration
		)
	}

	// MARK: - Preview / Test Container (en mémoire uniquement)

	/// Crée un `ModelContainer` en mémoire pour les Previews et les tests unitaires.
	///
	/// Les données ne sont jamais écrites sur disque. Le plan de migration est
	/// appliqué pour que les tests reflètent le comportement réel de production.
	static func makePreviewContainer() throws -> ModelContainer {
		let schema = currentSchema
		let configuration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: true,
			allowsSave: true,
			cloudKitDatabase: .none
		)

		return try ModelContainer(
			for: schema,
			migrationPlan: FinoriaMigrationPlan.self,
			configurations: configuration
		)
	}
}
