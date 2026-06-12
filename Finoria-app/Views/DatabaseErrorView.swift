//
//  DatabaseErrorView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/03/2026.
//

import SwiftUI

/// Vue affichée quand le conteneur SwiftData ne peut pas être initialisé correctement.
///
/// Remplace `ContentView` dans le `WindowGroup` lorsque l'initialisation du conteneur
/// a échoué deux fois (CloudKit puis fallback local) — voir `FinoriaApp.initErrorMessage`.
/// Affiche un message d'erreur clair et des suggestions de résolution pour l'utilisateur.
struct DatabaseErrorView: View {
	let errorMessage: String
	
	var body: some View {
		VStack(spacing: 24) {
			Spacer()
			
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 64))
				.foregroundStyle(.orange)
			
			Text("Problème de base de données")
				.font(.title2.bold())
			
			Text(errorMessage)
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 32)
			
			VStack(spacing: 12) {
				Text("Solutions possibles")
					.font(.headline)
				
				VStack(alignment: .leading, spacing: 10) {
					Label("Fermez et relancez l'application", systemImage: "arrow.clockwise")
					Label("Redémarrez votre appareil", systemImage: "power")
					Label("Réinstallez l'application", systemImage: "arrow.down.app")
				}
				.font(.subheadline)
				.foregroundStyle(.secondary)
			}
			.padding()
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
			.padding(.horizontal)
			
			Spacer()
		}
	}
}

#Preview {
	DatabaseErrorView(errorMessage: "Base de données inaccessible.\nVos données ne seront pas sauvegardées.\nRedémarrez l'app ou réinstallez-la.")
}
