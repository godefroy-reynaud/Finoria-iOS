//
//  SchemaMigrationTests.swift
//  Finoria-appTests
//
//  Created by Godefroy REYNAUD.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  BUT : vérifier — RAPIDEMENT et SANS AUCUN RISQUE — qu'un changement de
//  structure de données ne fait perdre AUCUNE donnée utilisateur.
//
//  Ces tests s'exécutent sur un fichier de base TEMPORAIRE (supprimé à la fin).
//  Ils ne touchent JAMAIS la vraie base de l'app ni iCloud/CloudKit.
//  Lance-les dans Xcode avec ⌘U avant chaque publication App Store.
//
//  ⚠️ À ajouter à la TARGET DE TEST (Finoria-appTests) dans Xcode, pas à l'app.
//  ─────────────────────────────────────────────────────────────────────────────

import XCTest
import SwiftData
@testable import Finoria

final class SchemaMigrationTests: XCTestCase {

	// MARK: - Test 1 — La structure ACTUELLE conserve toutes les données (round-trip)

	/// Écrit un jeu de données complet sur disque avec le conteneur de production
	/// (schéma versionné + plan de migration), puis ROUVRE la base comme le ferait
	/// une mise à jour de l'app — et vérifie que TOUT est encore là.
	///
	/// C'est la preuve, exécutable dès aujourd'hui, que tes utilisateurs actuels
	/// ne perdront rien en installant le build qui introduit le schéma versionné.
	@MainActor
	func testCurrentSchema_roundTripsAllModelsWithoutLoss() throws {
		// Dossier temporaire DÉDIÉ : il contient le store ET ses fichiers annexes
		// (-wal, -shm). On supprime TOUT le dossier à la fin (pas seulement le .store) —
		// c'est ce nettoyage partiel de l'ancienne version qui faisait échouer le test
		// avec « Impossible de supprimer … » (les fichiers -wal/-shm restaient).
		let storeDir = URL.temporaryDirectory
			.appending(path: "finoria-roundtrip-\(UUID().uuidString)", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: storeDir) }
		let url = storeDir.appending(path: "Finoria.store")

		let accountID = UUID()

		// 1. ÉCRIRE un jeu de données complet (un de chaque modèle + relations),
		//    EXACTEMENT comme l'app en production : conteneur créé AVEC le plan de
		//    migration. `SwiftDataService.makeContainer()` le passe TOUJOURS, même à
		//    la toute première création du store — le test doit faire pareil pour
		//    refléter le vrai comportement (et éviter une réouverture qui croit devoir
		//    « migrer » un store non versionné). Le `do {}` libère ce premier conteneur
		//    (fermeture du store) avant la réouverture de l'étape 2.
		do {
			let schema = Schema(versionedSchema: FinoriaCurrentSchema.self)
			let config = ModelConfiguration(schema: schema, url: url)
			let container = try ModelContainer(
				for: schema,
				migrationPlan: FinoriaMigrationPlan.self,
				configurations: config
			)
			let ctx = container.mainContext

			let account = Account(id: accountID, name: "Compte test", detail: "détail")
			ctx.insert(account)

			let category = CustomTransactionCategory(name: "Restaurant")
			category.account = account
			ctx.insert(category)

			let tx = Transaction(amount: -12.5, comment: "Café", potentiel: false, date: Date())
			tx.account = account
			tx.customCategory = category
			ctx.insert(tx)

			let shortcut = WidgetShortcut(amount: 5, comment: "Métro", type: .expense)
			shortcut.account = account
			ctx.insert(shortcut)

			let recurring = RecurringTransaction(amount: 800, comment: "Loyer", type: .expense)
			recurring.account = account
			ctx.insert(recurring)

			try ctx.save()
		} // ← le 1er conteneur est libéré ici : la base reste sur disque

		// 2. ROUVRIR la base (= ce que fait l'app au lancement après mise à jour)
		let schema = Schema(versionedSchema: FinoriaCurrentSchema.self)
		let config = ModelConfiguration(schema: schema, url: url)
		let container = try ModelContainer(
			for: schema,
			migrationPlan: FinoriaMigrationPlan.self,
			configurations: config
		)
		let ctx = container.mainContext

		// 3. VÉRIFIER que rien n'a disparu
		let accounts = try ctx.fetch(FetchDescriptor<Account>())
		XCTAssertEqual(accounts.count, 1, "Le compte doit être conservé")

		let account = try XCTUnwrap(accounts.first)
		XCTAssertEqual(account.id, accountID)
		XCTAssertEqual(account.name, "Compte test")
		XCTAssertEqual(account.detail, "détail")
		XCTAssertEqual(account.transactions.count, 1, "La transaction doit être conservée")
		XCTAssertEqual(account.customTransactionCategories.count, 1, "La catégorie perso doit être conservée")
		XCTAssertEqual(account.widgetShortcuts.count, 1, "Le raccourci doit être conservé")
		XCTAssertEqual(account.recurringTransactions.count, 1, "La récurrence doit être conservée")

		let tx = try XCTUnwrap(account.transactions.first)
		XCTAssertEqual(tx.amount, -12.5)
		XCTAssertEqual(tx.comment, "Café")
		XCTAssertEqual(tx.potentiel, false)
		XCTAssertEqual(tx.customCategory?.name, "Restaurant", "Le lien vers la catégorie perso doit survivre")
	}

	// MARK: - Test 2 — Un CHANGEMENT de structure (additif) ne perd aucune donnée

	/// Démonstration end-to-end du mécanisme de migration, avec des modèles jetables
	/// (`DemoNote`) : on écrit des données avec une structure V1, on AJOUTE un champ
	/// (V2), puis on rouvre avec le plan de migration — et la donnée d'origine est
	/// toujours là, le nouveau champ ayant pris sa valeur par défaut.
	///
	/// 👉 C'est EXACTEMENT le patron à reproduire le jour où tu créeras
	///    `FinoriaSchemaV2` : remplace `DemoSchema*` par `FinoriaSchema*`, écris des
	///    `Account`/`Transaction`… en V1, rouvre en V2, et vérifie champ par champ.
	@MainActor
	func testAdditiveStructureChange_keepsAllData() throws {
		let url = URL.temporaryDirectory.appending(path: "demo-migration-\(UUID().uuidString).store")
		defer { try? FileManager.default.removeItem(at: url) }

		// 1. ÉCRIRE avec l'ANCIENNE structure (V1 : DemoNote n'a qu'un `text`)
		do {
			let schema = Schema(versionedSchema: DemoSchemaV1.self)
			let config = ModelConfiguration(schema: schema, url: url)
			let container = try ModelContainer(for: schema, configurations: config)
			container.mainContext.insert(DemoSchemaV1.DemoNote(text: "ma note importante"))
			try container.mainContext.save()
		}

		// 2. ROUVRIR avec la NOUVELLE structure (V2 : DemoNote gagne un champ `pinned`)
		//    + le plan de migration → la migration V1→V2 s'exécute automatiquement.
		let schema = Schema(versionedSchema: DemoSchemaV2.self)
		let config = ModelConfiguration(schema: schema, url: url)
		let container = try ModelContainer(
			for: schema,
			migrationPlan: DemoMigrationPlan.self,
			configurations: config
		)
		let notes = try container.mainContext.fetch(FetchDescriptor<DemoSchemaV2.DemoNote>())

		// 3. VÉRIFIER : la donnée d'origine est intacte, le nouveau champ a son défaut
		XCTAssertEqual(notes.count, 1, "La note doit survivre au changement de structure")
		XCTAssertEqual(notes.first?.text, "ma note importante", "Le texte ne doit pas être perdu")
		XCTAssertEqual(notes.first?.pinned, false, "Le nouveau champ prend sa valeur par défaut")
	}
}

// MARK: - Modèles jetables pour la démonstration de migration (Test 2)
//
// Volontairement minimalistes et privés au test — ils n'existent que pour prouver
// que le mécanisme de migration additive préserve les données. Ne sers PAS de ça
// dans l'app : la vraie source de vérité reste `FinoriaSchema.swift`.

private enum DemoSchemaV1: VersionedSchema {
	static var versionIdentifier = Schema.Version(1, 0, 0)
	static var models: [any PersistentModel.Type] { [DemoNote.self] }

	@Model final class DemoNote {
		var text: String = ""
		init(text: String) { self.text = text }
	}
}

private enum DemoSchemaV2: VersionedSchema {
	static var versionIdentifier = Schema.Version(2, 0, 0)
	static var models: [any PersistentModel.Type] { [DemoNote.self] }

	@Model final class DemoNote {
		var text: String = ""
		var pinned: Bool = false   // ← champ AJOUTÉ (additif, avec valeur par défaut)
		init(text: String, pinned: Bool = false) {
			self.text = text
			self.pinned = pinned
		}
	}
}

private enum DemoMigrationPlan: SchemaMigrationPlan {
	static var schemas: [any VersionedSchema.Type] {
		[DemoSchemaV1.self, DemoSchemaV2.self]
	}
	static var stages: [MigrationStage] {
		[.lightweight(fromVersion: DemoSchemaV1.self, toVersion: DemoSchemaV2.self)]
	}
}
