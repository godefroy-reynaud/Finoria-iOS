//
//  ContentView.swift
//  GDF-app
//
//  Created by Godefroy REYNAUD on 03/10/2024.
//

import SwiftUI
import SwiftData

/// Vue racine de l'application avec TabView principale
struct ContentView: View {
	// WHY: @Environment(Type.self) remplace @ObservedObject — l'objet @Observable
	// est injecté par FinoriaApp via .environment(accountsManager).
	@Environment(AccountsManager.self) private var accountsManager

	// WHY: @Query remplace accountsManager.getAllAccounts() — lecture lazy
	// directement depuis SwiftData, utilisée pour l'auto-sélection du premier compte.
	@Query(sort: \Account.name) private var accounts: [Account]
	@State private var showingAddTransactionSheet = false
	@State private var addTransactionAsPotential = false
	@State private var tabSelection: TabItem = .home
	@Environment(\.scenePhase) private var scenePhase
	
	// MARK: - Welcome Sheet (premier lancement)
	// WHY: Clé centralisée dans AppStorageKeys (évite les typos silencieuses).
	@AppStorage(AppStorageKeys.hasSeenWelcome) private var hasSeenWelcome = false
	@State private var showWelcomeSheet = false
	
	// MARK: - CloudKit Alert
	@State private var showCloudKitAlert = false
	@State private var cloudKitAlertTitle = ""
	@State private var cloudKitAlertMessage = ""
	
	enum TabItem: Hashable {
		case home, analyses, calendrier, futur, add
	}
	
	var body: some View {
		TabView(selection: $tabSelection) {
			// Onglet Home
			Tab(value: TabItem.home) {
				HomeTabView()
					.sheet(isPresented: $showingAddTransactionSheet) {
						if accountsManager.selectedAccount != nil {
							AddTransactionView(initialIsPotentiel: addTransactionAsPotential)
						}
					}
			} label: {
				Label("Accueil", systemImage: "house")
			}

			// Onglet Analyses
			Tab(value: TabItem.analyses) {
				AnalysesTabView()
			} label: {
				Label("Analyses", systemImage: "chart.pie")
			}

			// Onglet Calendrier
			Tab(value: TabItem.calendrier) {
				CalendrierMainView()
			} label: {
				Label("Calendrier", systemImage: "calendar")
			}

			// Onglet Futur
			Tab(value: TabItem.futur) {
				FutureTabView()
			} label: {
				Label("Futur", systemImage: "clock.arrow.circlepath")
			}
			
			// Bouton Ajouter avec role search (séparé visuellement à droite)
			Tab(value: TabItem.add, role: .search) {
				Color.clear
			} label: {
				Label("", systemImage: "plus.circle.fill")
			}
		}
		.onChange(of: tabSelection) { oldValue, newValue in
			if newValue == .add {
				if accountsManager.selectedAccount != nil {
					addTransactionAsPotential = oldValue == .futur
					showingAddTransactionSheet = true
				}
				DispatchQueue.main.async {
					tabSelection = oldValue
				}
			}
		}
		.onAppear {
			// Auto-sélection du premier compte si aucun n'est sélectionné ou si le compte n'existe plus
			if accountsManager.selectedAccount == nil {
				accountsManager.selectedAccountId = accounts.first?.id
			}
			// Générer les transactions récurrentes à venir / valider celles du jour
			accountsManager.processRecurringTransactions()
			// Vérifier le statut CloudKit au lancement
			checkCloudKit()
			// Afficher la sheet de bienvenue au premier lancement
			if !hasSeenWelcome {
				showWelcomeSheet = true
			}
		}
		.onChange(of: scenePhase) { _, newPhase in
			if newPhase == .active {
				// Rafraîchir les données depuis SwiftData (récupère les changements CloudKit)
				accountsManager.refreshFromStore()
				// Retraiter les récurrences quand l'app revient au premier plan
				accountsManager.processRecurringTransactions()
			}
		}
		.alert(cloudKitAlertTitle, isPresented: $showCloudKitAlert) {
			Button("OK", role: .cancel) { }
		} message: {
			Text(cloudKitAlertMessage)
		}
		.sheet(isPresented: $showWelcomeSheet, onDismiss: {
			hasSeenWelcome = true
		}) {
			WelcomeView()
		}
	}
	
	// MARK: - CloudKit Check
	
	/// Vérifie que CloudKit est fonctionnel et affiche une alerte si ce n'est pas le cas.
	private func checkCloudKit() {
		Task {
			let status = await CloudKitService.checkAccountStatus()
			if !status.isAvailable {
				await MainActor.run {
					cloudKitAlertTitle = status.alertTitle
					cloudKitAlertMessage = status.userMessage
					showCloudKitAlert = true
				}
			}
		}
	}
}

#Preview {
	ContentView()
		.environment(AccountsManager.preview)
}
