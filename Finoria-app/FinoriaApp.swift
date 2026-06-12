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
	
	/// Conteneur SwiftData partagé pour toute l'application
	let modelContainer: ModelContainer
	
	/// Gestionnaire des comptes (source de vérité)
	// WHY: @State remplace @StateObject pour un objet @Observable —
	// SwiftUI garde l'instance en vie pour la durée de vie de la scène.
	@State private var accountsManager: AccountsManager
	
	init() {
		// 1. Créer le conteneur SwiftData (CloudKit activé)
		// Note : makeContainer() avec .automatic ne crash quasiment jamais.
		// Si CloudKit est indisponible (pas de compte iCloud, simulateur, etc.),
		// SwiftData fonctionne en local et synchronise plus tard quand c'est possible.
		// Le diagnostic CloudKit est fait dans ContentView via CloudKitService.
		let container: ModelContainer
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
				fatalError("Impossible de créer le ModelContainer: \(error)")
			}
		}
		self.modelContainer = container
		
		// 2. Créer l'AccountsManager avec le contexte du conteneur
		let manager = AccountsManager(modelContext: container.mainContext)
		_accountsManager = State(initialValue: manager)
		
		// 3. Notifications
		NotificationManager.shared.requestNotificationPermission()
		NotificationManager.shared.scheduleWeeklyNotificationIfNeeded()
		
		// 4. Subscription CloudKit pour les notifications push (annonces)
		Task {
			await CloudKitService.subscribeToAnnouncements()
		}
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				// WHY: Injection par environnement (.environment, pas .environmentObject) —
				// toutes les vues descendantes lisent via @Environment(AccountsManager.self).
				.environment(accountsManager)
		}
		.modelContainer(modelContainer)
	}
}
