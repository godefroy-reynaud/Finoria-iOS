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
//  Ils ne touchent JAMAIS la vraie base de l'app ni iCloud/CloudKit
//  (tous les conteneurs utilisent `cloudKitDatabase: .none`).
//  Lance-les dans Xcode avec ⌘U avant chaque publication App Store.
//
//  • Test 1 — store EN MÉMOIRE (comme le conteneur de preview de l'app) : vérifie
//    que le schéma courant accepte et restitue TOUS les modèles + relations.
//  • Test 2 — store sur FICHIER + plan de migration : vérifie qu'un changement de
//    structure (ajout de champ V1→V2) conserve les données. C'est LA preuve
//    « une mise à jour ne perd aucune donnée ».
//
//  ⚠️ À ajouter à la TARGET DE TEST (Finoria-appTests) dans Xcode, pas à l'app.
//  ─────────────────────────────────────────────────────────────────────────────

import XCTest
import SwiftData
@testable import Finoria

final class SchemaMigrationTests: XCTestCase {

	// MARK: - Test 1 — Le schéma courant accepte et restitue tous les modèles

	/// Insère un de chaque modèle (avec leurs relations) dans le schéma versionné
	/// courant, puis relit le tout depuis le store via un CONTEXTE NEUF et vérifie
	/// que rien ne manque.
	///
	/// Store EN MÉMOIRE — exactement le montage utilisé par le conteneur de preview
	/// de l'app (`SwiftDataService.makePreviewContainer`), donc fiable et sans aucun
	/// fichier à gérer. But : garantir que la structure actuelle est saine et
	/// entièrement persistable. Le mécanisme de MIGRATION (changement de structure
	/// sans perte) est prouvé séparément par le test 2.
	@MainActor
	func testCurrentSchema_persistsEveryModelAndRelation() throws {
		let schema = Schema(versionedSchema: FinoriaCurrentSchema.self)
		let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
		let container = try ModelContainer(for: schema, configurations: config)

		let accountID = UUID()

		// 1. ÉCRIRE un jeu de données complet (un de chaque modèle + relations)
		let writeCtx = container.mainContext

		let account = Account(id: accountID, name: "Compte test", detail: "détail")
		writeCtx.insert(account)

		let category = CustomTransactionCategory(name: "Restaurant")
		category.account = account
		writeCtx.insert(category)

		let tx = Transaction(amount: -12.5, comment: "Café", potentiel: false, date: Date())
		tx.account = account
		tx.customCategory = category
		writeCtx.insert(tx)

		let shortcut = WidgetShortcut(amount: 5, comment: "Métro", type: .expense)
		shortcut.account = account
		writeCtx.insert(shortcut)

		let recurring = RecurringTransaction(amount: 800, comment: "Loyer", type: .expense)
		recurring.account = account
		writeCtx.insert(recurring)

		try writeCtx.save()

		// 2. RELIRE depuis le store via un contexte NEUF (et non le cache d'écriture)
		let readCtx = ModelContext(container)
		let accounts = try readCtx.fetch(FetchDescriptor<Account>())

		// 3. VÉRIFIER que rien n'a disparu, relations comprises
		XCTAssertEqual(accounts.count, 1, "Le compte doit être conservé")
		let fetched = try XCTUnwrap(accounts.first)
		XCTAssertEqual(fetched.id, accountID)
		XCTAssertEqual(fetched.name, "Compte test")
		XCTAssertEqual(fetched.detail, "détail")
		XCTAssertEqual(fetched.transactions.count, 1, "La transaction doit être conservée")
		XCTAssertEqual(fetched.customTransactionCategories.count, 1, "La catégorie perso doit être conservée")
		XCTAssertEqual(fetched.widgetShortcuts.count, 1, "Le raccourci doit être conservé")
		XCTAssertEqual(fetched.recurringTransactions.count, 1, "La récurrence doit être conservée")

		let fetchedTx = try XCTUnwrap(fetched.transactions.first)
		XCTAssertEqual(fetchedTx.amount, -12.5)
		XCTAssertEqual(fetchedTx.comment, "Café")
		XCTAssertEqual(fetchedTx.potentiel, false)
		XCTAssertEqual(fetchedTx.customCategory?.name, "Restaurant", "Le lien vers la catégorie perso doit survivre")
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
			let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
			let container = try ModelContainer(for: schema, configurations: config)
			container.mainContext.insert(DemoSchemaV1.DemoNote(text: "ma note importante"))
			try container.mainContext.save()
		}

		// 2. ROUVRIR avec la NOUVELLE structure (V2 : DemoNote gagne un champ `pinned`)
		//    + le plan de migration → la migration V1→V2 s'exécute automatiquement.
		let schema = Schema(versionedSchema: DemoSchemaV2.self)
		let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
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
