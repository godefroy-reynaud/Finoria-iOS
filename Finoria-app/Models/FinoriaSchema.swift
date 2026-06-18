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

// MARK: - Schéma V1 (structure ACTUELLE — figée, ne pas modifier)

/// Version 1 du schéma de données Finoria.
///
/// ⚠️ NE PAS MODIFIER cette version : elle décrit la structure déjà déployée
/// chez les utilisateurs. Pour tout changement, créez `FinoriaSchemaV2`.
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

// MARK: - Plan de migration (l'historique de toutes les versions)

/// Décrit l'enchaînement des versions de schéma et la façon de passer de l'une
/// à l'autre sans perte de données.
///
/// Tant qu'il n'y a qu'une seule version, `stages` est vide : SwiftData ouvre
/// le store tel quel. Dès qu'une `FinoriaSchemaV2` existe, ajoutez-la ici ainsi
/// que l'étape `V1 → V2`.
enum FinoriaMigrationPlan: SchemaMigrationPlan {

	/// Toutes les versions du schéma, de la plus ancienne à la plus récente.
	/// AJOUTEZ ici chaque nouvelle version (ne retirez JAMAIS une version passée).
	static var schemas: [any VersionedSchema.Type] {
		[
			FinoriaSchemaV1.self
			// , FinoriaSchemaV2.self   ← à ajouter lors du prochain changement
		]
	}

	/// Les étapes de transformation entre versions successives.
	/// Vide pour l'instant : une seule version existe, aucune migration requise.
	static var stages: [MigrationStage] {
		[
			// Exemple à décommenter/adapter pour la V2 :
			//
			// — Migration ADDITIVE (cas A, automatique) :
			// .lightweight(fromVersion: FinoriaSchemaV1.self,
			//              toVersion:   FinoriaSchemaV2.self),
			//
			// — Migration COMPLEXE (cas B, manuelle, sans perte) :
			// .custom(
			//     fromVersion: FinoriaSchemaV1.self,
			//     toVersion:   FinoriaSchemaV2.self,
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
/// la SEULE ligne à modifier ici (la faire pointer vers `FinoriaSchemaV2`).
typealias FinoriaCurrentSchema = FinoriaSchemaV1
