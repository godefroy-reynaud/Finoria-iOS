//
//  WelcomeView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 09/03/2026.
//

import SwiftUI

/// Sheet de bienvenue affichée au premier lancement, style Apple "What's New".
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [Feature] = [
        Feature(
            icon: "banknote",
            color: .green,
            title: "Gestion multi-comptes",
            description: "Créez et gérez plusieurs comptes avec des styles personnalisés."
        ),
        Feature(
            icon: "arrow.left.arrow.right",
            color: .blue,
            title: "Transactions rapides",
            description: "Ajoutez revenus et dépenses en quelques secondes grâce aux raccourcis."
        ),
        Feature(
            icon: "repeat",
            color: .orange,
            title: "Transactions récurrentes",
            description: "Automatisez vos dépenses et revenus réguliers : loyer, salaire, abonnements…"
        ),
        Feature(
            icon: "chart.pie",
            color: .purple,
            title: "Analyses détaillées",
            description: "Visualisez la répartition de vos dépenses et revenus par catégorie."
        ),
        Feature(
            icon: "calendar",
            color: .red,
            title: "Navigation temporelle",
            description: "Explorez vos finances par jour, mois ou année dans le calendrier."
        ),
        Feature(
            icon: "clock.arrow.circlepath",
            color: .teal,
            title: "Prévisions futures",
            description: "Anticipez votre solde avec les transactions à venir et récurrentes."
        ),
        Feature(
            icon: "icloud",
            color: .cyan,
            title: "Synchronisation iCloud",
            description: "Vos données sont synchronisées automatiquement sur tous vos appareils Apple."
        ),
        Feature(
            icon: "tag",
            color: .indigo,
            title: "Catégories personnalisées",
            description: "Créez vos propres catégories avec une icône et une couleur pour mieux organiser vos transactions."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // MARK: - Header
                VStack(spacing: 8) {
                    Text("Bienvenue dans")
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Finoria")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)

                // MARK: - Features list
                VStack(spacing: 24) {
                    ForEach(features) { feature in
                        FeatureRow(feature: feature)
                    }
                }
                .padding(.horizontal, 24)

                // MARK: - Continue button
                Button {
                    dismiss()
                } label: {
                    Text("Continuer")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: 200)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 16)
            }
            .padding(.bottom, 40)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Feature Model

private struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let description: String
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let feature: Feature

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundStyle(feature.color)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.subheadline.weight(.semibold))
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
}
