//
//  HomeTabView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 01/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Export CSV (Transferable)

/// Erreur levée si la génération du CSV échoue au moment du partage.
enum CSVExportError: Error {
	case generationFailed
}

/// Représente l'export CSV du compte sélectionné pour `ShareLink`.
///
// WHY: Remplace la présentation manuelle d'UIActivityViewController via la hiérarchie
// de fenêtres UIKit (fragile, cassait en multitâche iPad). Le CSV est généré
// À LA DEMANDE — dans la closure `exporting`, exécutée uniquement quand l'utilisateur
// déclenche le partage — et non au rendu de la vue, ce qui corrige le bug
// de sheet blanche au premier lancement.
struct CSVExport: Transferable {
	// WHY: AccountsManager est @MainActor donc implicitement Sendable —
	// requis car la closure `exporting` est @Sendable.
	let accountsManager: AccountsManager

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: .commaSeparatedText) { export in
			// WHY (FIX E): l'ancienne version appelait generateCSV() sur le main
			// actor — tri + formatage + écriture fichier gelaient l'UI plusieurs
			// secondes. Désormais : 1) snapshot rapide des données sur le main
			// actor, 2) génération lourde ici-même, dans cette closure @Sendable
			// qui s'exécute en arrière-plan.
			guard let snapshot = await export.accountsManager.beginCSVExport() else {
				throw CSVExportError.generationFailed
			}
			defer {
				Task { @MainActor in export.accountsManager.endCSVExport() }
			}
			guard let url = CSVService.generateCSV(rows: snapshot.rows, accountName: snapshot.accountName) else {
				throw CSVExportError.generationFailed
			}
			return SentTransferredFile(url)
		}
	}
}

/// Vue principale de l'onglet Home avec toolbar et gestion CSV
struct HomeTabView: View {
	@Environment(AccountsManager.self) private var accountsManager
	@State private var showingAccountPicker = false
	@State private var showingDocumentPicker = false
	@State private var importedCount: Int = 0
	@State private var showImportSuccessAlert = false
	@State private var showImportErrorAlert = false
	
	var body: some View {
		NavigationStack {
			Group {
				if accountsManager.selectedAccount != nil {
					HomeView()
						.navigationBarTitleDisplayMode(.inline)
						.toolbar {
							ToolbarItem(placement: .navigationBarLeading) {
								HStack(spacing: 3) {
									// WHY: ShareLink natif (ancrage popover iPad géré par le système).
									ShareLink(
										item: CSVExport(accountsManager: accountsManager),
										preview: SharePreview("Export Finoria")
									) {
										// WHY (FIX E): spinner pendant la génération du CSV
										// pour signaler que l'export est en cours.
										if accountsManager.isExportingCSV {
											ProgressView()
												.scaleEffect(0.8)
												.padding(8)
										} else {
											Image(systemName: "square.and.arrow.up")
												.imageScale(.large)
												.padding(8)
										}
									}
									// WHY: Désactivé s'il n'y a rien à exporter — remplace
									// l'ancienne alerte "Erreur d'export" (CSV vide → URL nil).
									.disabled(accountsManager.transactions().isEmpty || accountsManager.isExportingCSV)
									Button { showingDocumentPicker = true } label: {
										Image(systemName: "square.and.arrow.down")
											.imageScale(.large)
											.padding(8)
									}
								}
							}
						}
						.sheet(isPresented: $showingDocumentPicker) {
							DocumentPicker { url in importCSV(from: url) }
						}
						.alert("Import réussi", isPresented: $showImportSuccessAlert) {
							Button("OK", role: .cancel) {}
						} message: {
							Text("\(importedCount) transaction(s) importée(s) avec succès.")
						}
						.alert("Erreur d'import", isPresented: $showImportErrorAlert) {
							Button("OK", role: .cancel) {}
						} message: {
							Text("Aucune transaction n'a pu être importée. Vérifiez le format du fichier CSV.")
						}
				} else {
					NoAccountView()
				}
			}
			.accountPickerToolbar(isPresented: $showingAccountPicker)
		}
	}
	
	// MARK: - Import CSV
	private func importCSV(from url: URL) {
		let count = accountsManager.importCSV(from: url)
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
