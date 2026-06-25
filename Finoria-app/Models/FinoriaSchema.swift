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
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠️⚠️  PIÈGE MAJEUR — POURQUOI `stages` EST VIDE  ⚠️⚠️                     ║
// ║                                                                            ║
// ║  Les `VersionedSchema` ci-dessous (FinoriaSchemaV1, …) RÉFÉRENCENT tous   ║
// ║  les MÊMES types `@Model` vivants (Account, Transaction, …). Conséquence :║
// ║  deux versions produisent un schéma au checksum IDENTIQUE.                ║
// ║                                                                            ║
// ║  → Ajouter une `MigrationStage.lightweight(V1 → V2)` entre deux versions  ║
// ║    au checksum identique fait CRASHER l'app au lancement                  ║
// ║    (`NSLightweightMigrationStage initWithVersionChecksums:` lève une      ║
// ║    NSException non rattrapable → abort). C'est un crash 100 % reproductible║
// ║    qui empêche TOUTE ouverture du store. Déjà arrivé (build 286).         ║
// ║                                                                            ║
// ║  RÈGLE : tant que les versions partagent les mêmes types @Model, on LAISSE║
// ║  `stages` VIDE. SwiftData fait alors une migration légère AUTOMATIQUE,    ║
// ║  qui suffit pour TOUS les changements additifs (nouveau champ avec        ║
// ║  défaut, nouveau @Model, nouvelle relation/inverse optionnel).            ║
// ╚══════════════════════════════════════════════════════════════════════════╝
//
// 2. Choisissez le TYPE de changement :
//
//    ┌─ A. CHANGEMENT ADDITIF (le cas simple et recommandé) ────────────────┐
//    │  • Ajouter une nouvelle propriété AVEC une valeur par défaut         │
//    │  • Ajouter un nouveau @Model                                          │
//    │  • Ajouter une relation / un inverse OPTIONNEL                        │
//    │                                                                      │
//    │  → Compatible CloudKit ET migré AUTOMATIQUEMENT par SwiftData.       │
//    │  → Modifiez directement les @Model existants. NE créez PAS d'étape   │
//    │    de migration, NE bumpez PAS la version : laissez `stages` vide.   │
//    │    La migration légère automatique s'occupe de tout sans perte.      │
//    └──────────────────────────────────────────────────────────────────────┘
//
//    ┌─ B. CHANGEMENT COMPLEXE (renommer, fusionner, transformer) ──────────┐
//    │  • Renommer une propriété / un modèle                                │
//    │  • Découper ou fusionner des modèles                                 │
//    │  • Transformer une valeur (ex. centimes → euros)                     │
//    │                                                                      │
//    │  → Nécessite une vraie migration par étapes. MAIS pour qu'une        │
//    │    `MigrationStage` fonctionne, CHAQUE version DOIT figer SA PROPRE   │
//    │    COPIE des @Model concernés (types imbriqués/namespacés dans le    │
//    │    `enum VersionedSchema`), et NON les types partagés actuels —      │
//    │    sinon checksums identiques → crash (voir l'encadré ci-dessus).    │
//    │  → ⚠️ CloudKit n'accepte PAS la suppression/renommage destructif.    │
//    │    Préférez : AJOUTER le nouveau champ, recopier la donnée, et       │
//    │    GARDER l'ancien (déprécié) plutôt que de le supprimer.            │
//    └──────────────────────────────────────────────────────────────────────┘
//
// 3. TESTEZ sur un appareil contenant des données de l'ancienne version AVANT
//    de publier (créez des données avec l'ancien build, installez le nouveau
//    par-dessus : aucune donnée ne doit disparaître, aucun crash au lancement).
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

/// Version 1 (et courante) du schéma de données Finoria.
///
/// ⚠️ NE PAS MODIFIER l'identifiant de version : il décrit la structure du store.
/// Les changements ADDITIFS (nouveau champ avec défaut, nouveau @Model, nouvelle
/// relation/inverse optionnel) se font en éditant directement les @Model — SwiftData
/// migre automatiquement (voir l'encadré « PIÈGE MAJEUR » en haut du fichier : tant
/// que les versions partagent les mêmes types @Model, on NE crée PAS de nouvelle
/// version ni d'étape de migration, sinon crash au lancement).
///
/// Les types `@Model` réels sont définis dans leurs fichiers respectifs
/// (`Account.swift`, `Transaction.swift`, etc.). Cette énumération ne fait que
/// les RÉFÉRENCER pour figer la composition du schéma.
enum FinoriaSchemaV1: VersionedSchema {

	/// Identifiant de version stocké dans les métadonnées du store.
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
/// `stages` est VIDE et doit le rester tant que les `VersionedSchema` partagent les
/// mêmes types `@Model` (voir l'encadré « PIÈGE MAJEUR » en haut du fichier) :
/// SwiftData applique une migration légère AUTOMATIQUE pour tous les changements
/// additifs, sans étape explicite — qui, elle, crasherait au lancement.
enum FinoriaMigrationPlan: SchemaMigrationPlan {

	/// Toutes les versions du schéma, de la plus ancienne à la plus récente.
	static var schemas: [any VersionedSchema.Type] {
		[
			FinoriaSchemaV1.self
		]
	}

	/// Les étapes de transformation entre versions successives.
	/// ⚠️ NE PAS ajouter de `.lightweight(...)` entre des versions qui réutilisent
	/// les mêmes types @Model : leurs checksums sont identiques → crash au lancement
	/// (`NSLightweightMigrationStage`). Pour une vraie migration par étapes, figer
	/// d'abord des copies de modèles par version (voir l'en-tête, cas B).
	static var stages: [MigrationStage] {
		[]
	}
}

// MARK: - Schéma courant (le SEUL endroit à mettre à jour pour activer une version)

/// Pointe TOUJOURS vers la dernière version du schéma.
///
/// `SwiftDataService` construit le `ModelContainer` à partir de cet alias et de
/// `FinoriaMigrationPlan`. Les changements additifs ne nécessitent PAS de nouvelle
/// version (migration automatique) ; ne créer une nouvelle version + la pointer ici
/// que pour une vraie migration par étapes à modèles figés (voir l'en-tête).
typealias FinoriaCurrentSchema = FinoriaSchemaV1
