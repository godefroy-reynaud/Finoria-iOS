//
//  HomeTabView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 01/01/2026.
//

import SwiftUI

/// Vue principale de l'onglet Home avec toolbar et gestion CSV
struct HomeTabView: View {
	@Environment(AccountsManager.self) private var accountsManager
	@State private var showingAccountPicker = false
	@State private var showingDocumentPicker = false
	@State private var importedCount: Int = 0
	@State private var showImportSuccessAlert = false
	@State private var showImportErrorAlert = false
	@State private var csvURL: URL? = nil
	@State private var showNoTransactionAlert = false

	// Confirmation avant import : transactions lues dans le fichier mais pas encore
	// enregistrées. On attend que l'utilisateur confirme le nombre avant d'écrire.
	@State private var pendingImport: [Transaction] = []
	@State private var showImportConfirmation = false

	// WHY: combinaison account + dataVersion comme identifiant de tâche — la tâche
	// redémarre dès qu'un compte est changé (persistentModelID change) OU qu'une
	// transaction est modifiée/ajoutée/supprimée (dataVersion s'incrémente dans
	// persist()). Le CSV est ainsi toujours à jour et ShareLink s'ouvre
	// instantanément car le fichier est déjà prêt quand l'utilisateur appuie.
	private var csvTaskID: String {
		let accountPart = accountsManager.selectedAccount?.persistentModelID.hashValue.description ?? "none"
		return "\(accountPart)-\(accountsManager.dataVersion)"
	}

	var body: some View {
		NavigationStack {
			Group {
				if accountsManager.selectedAccount != nil {
					HomeView()
						.navigationBarTitleDisplayMode(.inline)
						.toolbar {
							ToolbarItem(placement: .navigationBarLeading) {
								HStack(spacing: 3) {
									if let url = csvURL {
										ShareLink(
											item: url,
											preview: SharePreview("Export Finoria")
										) {
											Image(systemName: "square.and.arrow.up")
												.imageScale(.large)
												.padding(8)
										}
										.accessibilityLabel("Exporter en CSV")
									} else {
										Button { showNoTransactionAlert = true } label: {
											Image(systemName: "square.and.arrow.up")
												.imageScale(.large)
												.padding(8)
										}
										.foregroundStyle(.tertiary)
										.accessibilityLabel("Exporter en CSV")
									}
									Button { showingDocumentPicker = true } label: {
										Image(systemName: "square.and.arrow.down")
											.imageScale(.large)
											.padding(8)
									}
									.accessibilityLabel("Importer un CSV")
								}
							}
						}
						// WHY: task(id:) annule et relance la génération dès que csvTaskID
						// change (account ou données). Le snapshot se fait sur le main actor
						// (ici, dans la task qui hérite du contexte @MainActor de la vue),
						// puis la génération lourde part dans un Task.detached pour ne pas
						// bloquer l'UI. L'ancien csvURL est conservé jusqu'à ce que le
						// nouveau soit prêt — pas de flash "bouton désactivé" pendant la
						// brève régénération.
						.task(id: csvTaskID) {
							await prepareCSV()
						}
						.sheet(isPresented: $showingDocumentPicker) {
							DocumentPicker { url in handlePickedCSV(from: url) }
						}
						.alert("Import réussi", isPresented: $showImportSuccessAlert) {
							Button("OK", role: .cancel) {}
						} message: {
							Text("\(importedCount) transaction(s) importée(s) avec succès.")
						}
						.alert("Aucune transaction", isPresented: $showNoTransactionAlert) {
							Button("OK", role: .cancel) {}
						} message: {
							Text("Ce compte ne contient aucune transaction à exporter.")
						}
						.alert("Erreur d'import", isPresented: $showImportErrorAlert) {
							Button("OK", role: .cancel) {}
						} message: {
							Text("Aucune transaction n'a pu être importée. Vérifiez le format du fichier CSV.")
						}
						.alert("Confirmer l'import", isPresented: $showImportConfirmation) {
							Button("Importer") { confirmImport() }
							Button("Annuler", role: .cancel) { pendingImport = [] }
						} message: {
							Text("\(pendingImport.count) transaction(s) vont être ajoutées à ce compte.\n\nLes transactions existantes ne sont pas remplacées : réimporter le même fichier crée des doublons.")
						}
				} else {
					NoAccountView()
				}
			}
			.accountPickerToolbar(isPresented: $showingAccountPicker)
		}
	}

	// MARK: - Export CSV

	private func prepareCSV() async {
		guard let snapshot = accountsManager.csvExportSnapshot() else {
			csvURL = nil
			return
		}
		let newURL = await Task.detached(priority: .utility) {
			CSVService.generateCSV(rows: snapshot.rows, accountName: snapshot.accountName)
		}.value
		csvURL = newURL
	}

	// MARK: - Import CSV

	/// Étape 1 — lecture : on lit le fichier choisi SANS rien enregistrer. Si des
	/// transactions sont trouvées, on demande confirmation ; sinon on signale l'erreur.
	private func handlePickedCSV(from url: URL) {
		let parsed = accountsManager.parseCSVForImport(from: url)
		if parsed.isEmpty {
			showImportErrorAlert = true
		} else {
			pendingImport = parsed
			showImportConfirmation = true
		}
	}

	/// Étape 2 — enregistrement : l'utilisateur a confirmé, on écrit réellement.
	private func confirmImport() {
		let count = accountsManager.commitImportedTransactions(pendingImport)
		pendingImport = []
		importedCount = count
		if count > 0 {
			showImportSuccessAlert = true
		} else {
			showImportErrorAlert = true
		}
	}
}

#Preview {
	HomeTabView()
		.environment(AccountsManager.preview)
}
