//
//  FinoriaApp.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 03/10/2024.
//

import SwiftUI
import SwiftData
import os.log

@main
struct FinoriaApp: App {

	private static let logger = Logger(
		subsystem: Bundle.main.bundleIdentifier ?? "com.finoria",
		category: "FinoriaApp"
	)

	/// AppDelegate pour gérer les notifications push (CloudKit + push visibles)
	@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

	/// Conteneur SwiftData partagé pour toute l'application.
	// WHY (FIX F): optionnel — nil si l'initialisation a échoué deux fois
	// (CloudKit PUIS fallback local). Dans ce cas on affiche DatabaseErrorView
	// au lieu de crasher au lancement avec fatalError.
	let modelContainer: ModelContainer?

	/// Message d'erreur si la base de données n'a pas pu être initialisée
	let initErrorMessage: String?

	/// Gestionnaire des comptes (source de vérité ; nil si pas de conteneur)
	// WHY: @State remplace @StateObject pour un objet @Observable —
	// SwiftUI garde l'instance en vie pour la durée de vie de la scène.
	@State private var accountsManager: AccountsManager?

	init() {
		// 1. Créer le conteneur SwiftData (CloudKit activé)
		// Note : makeContainer() avec .automatic ne crash quasiment jamais.
		// Si CloudKit est indisponible (pas de compte iCloud, simulateur, etc.),
		// SwiftData fonctionne en local et synchronise plus tard quand c'est possible.
		// Le diagnostic CloudKit est fait dans ContentView via CloudKitService.
		var container: ModelContainer? = nil
		var errorMessage: String? = nil
		do {
			container = try SwiftDataService.makeContainer()
			Self.logger.info("ModelContainer créé (CloudKit .automatic)")
		} catch {
			Self.logger.error("Erreur création ModelContainer avec CloudKit: \(error.localizedDescription)")
			// Fallback : conteneur SUR DISQUE sans CloudKit (données conservées !)
			do {
				container = try SwiftDataService.makeFallbackContainer()
				Self.logger.warning("Fallback: conteneur local sans CloudKit (données sur disque)")
			} catch {
				// WHY (FIX F): plus de fatalError — on mémorise l'erreur et le body
				// affichera DatabaseErrorView avec des pistes de résolution.
				Self.logger.fault("Impossible de créer le ModelContainer: \(error.localizedDescription)")
				errorMessage = "La base de données n'a pas pu être initialisée.\n\(error.localizedDescription)"
			}
		}
		self.modelContainer = container
		self.initErrorMessage = errorMessage

		if let container {
			// 2. Créer l'AccountsManager avec le contexte du conteneur
			_accountsManager = State(initialValue: AccountsManager(modelContext: container.mainContext))

			// 3. Notifications locales (uniquement si l'app est fonctionnelle)
			NotificationManager.shared.requestNotificationPermission()
			NotificationManager.shared.scheduleWeeklyNotificationIfNeeded()
		} else {
			_accountsManager = State(initialValue: nil)
		}
	}

	var body: some Scene {
		WindowGroup {
			if let modelContainer, let accountsManager {
				ContentView()
					// WHY: Injection par environnement (.environment, pas .environmentObject) —
					// toutes les vues descendantes lisent via @Environment(AccountsManager.self).
					.environment(accountsManager)
					// WHY (FIX F): le conteneur est appliqué sur la vue (et non sur la
					// Scene) car il est optionnel — @Query le récupère via l'environnement.
					.modelContainer(modelContainer)
			} else {
				// WHY (FIX F): écran d'erreur gracieux au lieu d'un crash au lancement.
				DatabaseErrorView(
					errorMessage: initErrorMessage
						?? "La base de données n'a pas pu être initialisée."
				)
			}
		}
	}
}
