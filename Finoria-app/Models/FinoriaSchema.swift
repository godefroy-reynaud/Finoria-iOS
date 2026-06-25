//
//  FinoriaSchema.swift
//  Finoria
//
//  Created by Godefroy REYNAUD.
//

import Foundation
import SwiftData

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️  MIGRATION DES DONNÉES — À LIRE AVANT TOUT CHANGEMENT DE STRUCTURE  ⚠️ ║
// ╠══════════════════════════════════════════════════════════════════════════╣
// ║                                                                            ║
// ║  Ce fichier est le POINT DE CONTRÔLE UNIQUE pour faire évoluer la         ║
// ║  structure des données SANS JAMAIS perdre une donnée utilisateur          ║
// ║  (ni sur l'appareil, ni dans iCloud/CloudKit).                            ║
// ║                                                                            ║
// ║  RÈGLE D'OR : on ne modifie JAMAIS un `FinoriaSchemaVx` déjà publié.      ║
// ║  À chaque changement de structure, on CRÉE une nouvelle version (V2, V3…) ║
// ║  et on ajoute une « MigrationStage » qui décrit comment passer de         ║
// ║  l'ancienne à la nouvelle SANS perte.                                     ║
// ║                                                                            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// ─────────────────────────────────────────────────────────────────────────────
// COMMENT FAIRE ÉVOLUER LA STRUCTURE (procédure pas à pas)
// ─────────────────────────────────────────────────────────────────────────────
//
// 1. NE TOUCHEZ PAS au `FinoriaSchemaV1` ci-dessous : il fige la structure
//    déjà installée chez les utilisateurs. Le modifier = données illisibles.
//
// 2. Choisissez le TYPE de changement :
//
//    ┌─ A. CHANGEMENT ADDITIF (le cas simple et recommandé) ────────────────┐
//    │  • Ajouter une nouvelle propriété AVEC une valeur par défaut         │
//    │  • Ajouter un nouveau @Model                                          │
//    │  • Ajouter une relation OPTIONNELLE                                   │
//    │                                                                      │
//    │  → C'est compatible CloudKit ET migrable automatiquement.           │
//    │  → Modifiez directement les @Model existants, puis créez un          │
//    │    `FinoriaSchemaV2` (copie de V1 avec le changement) et une         │
//    │    `MigrationStage.lightweight(fromVersion: V1, toVersion: V2)`.     │
//    └──────────────────────────────────────────────────────────────────────┘
//
//    ┌─ B. CHANGEMENT COMPLEXE (renommer, fusionner, transformer) ──────────┐
//    │  • Renommer une propriété / un modèle                                │
//    │  • Découper ou fusionner des modèles                                 │
//    │  • Transformer une valeur (ex. centimes → euros)                     │
//    │                                                                      │
//    │  → Nécessite une `MigrationStage.custom(...)` avec un bloc           │
//    │    `willMigrate` / `didMigrate` qui RECOPIE les données de l'ancien  │
//    │    champ vers le nouveau AVANT que l'ancien ne disparaisse.          │
//    │  → ⚠️ CloudKit n'accepte PAS la suppression/renommage destructif.    │
//    │    Avec iCloud, préférez : AJOUTER le nouveau champ, recopier la     │
//    │    donnée, et GARDER l'ancien champ (marqué @available deprecated)   │
//    │    plutôt que de le supprimer. Voir la note CloudKit plus bas.       │
//    └──────────────────────────────────────────────────────────────────────┘
//
// 3. Créez `FinoriaSchemaV2` (voir le MODÈLE commenté tout en bas du fichier).
//
// 4. Ajoutez la nouvelle version dans `FinoriaMigrationPlan.schemas`
//    ET la `MigrationStage` correspondante dans `FinoriaMigrationPlan.stages`.
//
// 5. Faites pointer `FinoriaCurrentSchema` (en bas) vers la NOUVELLE version.
//    C'est la SEULE ligne à changer pour activer la nouvelle structure :
//    `SwiftDataService` lit le schéma courant + le plan de migration ici.
//
// 6. TESTEZ la migration sur un appareil contenant des données de l'ancienne
//    version AVANT de publier (installez l'ancien build, créez des données,
//    puis installez le nouveau build par-dessus : aucune donnée ne doit
//    disparaître).
//
// ─────────────────────────────────────────────────────────────────────────────
// CONTRAINTES CLOUDKIT (impératives — sinon la synchro casse)
// ─────────────────────────────────────────────────────────────────────────────
//   • Toute nouvelle propriété DOIT avoir une valeur par défaut.
//   • Toute relation to-one DOIT rester optionnelle côté enfant.
//   • Aucun `@Attribute(.unique)` (incompatible CloudKit).
//   • CloudKit ne supporte QUE les évolutions ADDITIVES de schéma : on peut
//     ajouter des champs/types, jamais en supprimer ou en renommer côté serveur.
//     Pour « renommer », on ajoute le nouveau champ et on migre les données.
//
// ─────────────────────────────────────────────────────────────────────────────
// FILET DE SÉCURITÉ SUPPLÉMENTAIRE (optionnel mais recommandé)
// ─────────────────────────────────────────────────────────────────────────────
//   Avant une migration de type B (complexe/risquée), on peut copier le fichier
//   de base SQLite sur disque (sauvegarde) avant l'ouverture du conteneur, et la
//   restaurer si l'ouverture échoue. À implémenter dans `SwiftDataService` le
//   jour où une migration complexe est introduite — pas nécessaire pour les
//   migrations additives (A), gérées nativement et sans risque par SwiftData.
//

// MARK: - Schéma V1 (première structure — figée, ne pas modifier)

/// Version 1 du schéma de données Finoria.
///
/// ⚠️ NE PAS MODIFIER cette version : elle décrit la première structure du store.
/// La structure COURANTE est `FinoriaSchemaV2` (voir plus bas). Pour tout nouveau
/// changement, créez `FinoriaSchemaV3`.
///
/// Les types `@Model` réels sont définis dans leurs fichiers respectifs
/// (`Account.swift`, `Transaction.swift`, etc.). Cette énumération ne fait que
/// les RÉFÉRENCER pour figer la composition du schéma à un instant donné.
enum FinoriaSchemaV1: VersionedSchema {

	/// Identifiant de version stocké dans les métadonnées du store.
	/// Sert au plan de migration à déterminer quelles étapes exécuter.
	static var versionIdentifier = Schema.Version(1, 0, 0)

	/// Liste exhaustive des modèles persistés dans cette version.
	static var models: [any PersistentModel.Type] {
		[
			Account.self,
			Transaction.self,
			WidgetShortcut.self,
			RecurringTransaction.self,
			CustomTransactionCategory.self
		]
	}
}

// MARK: - Schéma V2 (structure ACTUELLE — figée, ne pas modifier)

/// Version 2 du schéma de données Finoria.
///
/// CHANGEMENT par rapport à V1 — purement ADDITIF :
/// `CustomTransactionCategory` déclare désormais EXPLICITEMENT ses relations
/// inverses `widgetShortcuts` et `recurringTransactions` (auparavant synthétisées
/// implicitement par SwiftData). Aucune propriété scalaire n'est ajoutée ni retirée,
/// aucun lien existant n'est cassé → migration `.lightweight`, zéro perte de données.
///
/// ⚠️ NE PAS MODIFIER cette version une fois publiée : pour tout changement
/// ultérieur, créez `FinoriaSchemaV3` + une nouvelle `MigrationStage`.
enum FinoriaSchemaV2: VersionedSchema {

	static var versionIdentifier = Schema.Version(2, 0, 0)

	/// Même composition de modèles que V1 ; la différence est portée par la
	/// définition à jour de `CustomTransactionCategory` (inverses explicites).
	static var models: [any PersistentModel.Type] {
		[
			Account.self,
			Transaction.self,
			WidgetShortcut.self,
			RecurringTransaction.self,
			CustomTransactionCategory.self
		]
	}
}

// MARK: - Plan de migration (l'historique de toutes les versions)

/// Décrit l'enchaînement des versions de schéma et la façon de passer de l'une
/// à l'autre sans perte de données.
///
/// La première version publiée est `V1` ; la version courante est `V2` (ajout des
/// inverses explicites de `customCategory`). L'étape `V1 → V2` est une migration
/// légère (additive). Dès qu'une `FinoriaSchemaV3` existera, ajoutez-la ici ainsi
/// que l'étape `V2 → V3`.
enum FinoriaMigrationPlan: SchemaMigrationPlan {

	/// Toutes les versions du schéma, de la plus ancienne à la plus récente.
	/// AJOUTEZ ici chaque nouvelle version (ne retirez JAMAIS une version passée).
	static var schemas: [any VersionedSchema.Type] {
		[
			FinoriaSchemaV1.self,
			FinoriaSchemaV2.self
			// , FinoriaSchemaV3.self   ← à ajouter lors du prochain changement
		]
	}

	/// Les étapes de transformation entre versions successives.
	static var stages: [MigrationStage] {
		[
			// V1 → V2 : ADDITIF (inverses explicites de customCategory).
			// Aucune donnée à transformer → migration légère automatique.
			.lightweight(fromVersion: FinoriaSchemaV1.self,
						 toVersion:   FinoriaSchemaV2.self)

			// Modèle pour une future étape COMPLEXE (cas B, manuelle, sans perte) :
			// .custom(
			//     fromVersion: FinoriaSchemaV2.self,
			//     toVersion:   FinoriaSchemaV3.self,
			//     willMigrate: { context in
			//         // Recopier l'ancienne donnée vers le nouveau champ AVANT
			//         // que l'ancien ne disparaisse, puis context.save().
			//     },
			//     didMigrate: { context in
			//         // Nettoyage/normalisation APRÈS migration, si besoin.
			//     }
			// )
		]
	}
}

// MARK: - Schéma courant (le SEUL endroit à mettre à jour pour activer une version)

/// Pointe TOUJOURS vers la dernière version du schéma.
///
/// `SwiftDataService` construit le `ModelContainer` à partir de cet alias et de
/// `FinoriaMigrationPlan`. Lors de l'introduction d'une nouvelle version, c'est
/// la SEULE ligne à modifier ici (la faire pointer vers `FinoriaSchemaV3`, etc.).
typealias FinoriaCurrentSchema = FinoriaSchemaV2
