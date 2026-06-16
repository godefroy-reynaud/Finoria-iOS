//
//  HomeComponents.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import SwiftUI

// MARK: - Balance Header Content

/// Contenu de l'en-tête avec le solde total
/// Utilisé dans un NavigationLink dans HomeView
struct BalanceHeaderContent: View {
	let accountName: String?
	let totalCurrent: Double?
	let percentageChange: Double?
	
	var body: some View {
		VStack(spacing: 4) {
			if let accountName = accountName {
				Text(accountName)
					.scaledFont(size: 17, weight: .semibold)
					.foregroundStyle(.primary)
					.padding(.bottom, 8)
			}
			
			Text("Solde total")
				.scaledFont(size: 12, weight: .bold)
				.foregroundStyle(.secondary)
				.textCase(.uppercase)
				.tracking(2)
			
			if let totalCurrent = totalCurrent {
				Text("\(totalCurrent, specifier: "%.2f") €")
					.scaledFont(size: 48, weight: .bold, relativeTo: .largeTitle)
					.foregroundStyle(totalCurrent < 0 ? .red : .primary)
					.tracking(-1)
					.lineLimit(1)
					.minimumScaleFactor(0.5)
			}
			
			PercentageChangeIndicator(percentage: percentageChange)
		}
		.padding(.top, 16)
		.padding(.bottom, 16)
	}
}

// MARK: - Percentage Change Indicator

/// Indicateur de variation en pourcentage (flèche + texte coloré)
struct PercentageChangeIndicator: View {
	let percentage: Double?
	
	var body: some View {
		HStack(spacing: 4) {
			Image(systemName: iconName)
				.scaledFont(size: 12, weight: .semibold)
			Text(formattedText)
				.scaledFont(size: 14, weight: .semibold)
		}
		.foregroundStyle(color)
	}
	
	private var iconName: String {
		guard let p = percentage else { return "arrow.forward" }
		if p > 0 { return "arrow.up.right" }
		if p < 0 { return "arrow.down.right" }
		return "arrow.forward"
	}
	
	private var formattedText: String {
		guard let p = percentage else { return "+0.0% ce mois-ci" }
		let sign = p > 0 ? "+" : ""
		return "\(sign)\(String(format: "%.1f", p))% ce mois-ci"
	}
	
	private var color: Color {
		guard let p = percentage else { return .secondary }
		if p > 0 { return .green }
		if p < 0 { return .red }
		return .secondary
	}
}

// MARK: - Quick Card Content

/// Contenu d'une carte rapide (icône + titre + valeur)
/// Utilisé dans un NavigationLink dans HomeView
struct QuickCardContent: View {
	let icon: String
	let iconColor: Color
	let title: String
	let value: Double?
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Icône avec fond coloré
			ZStack {
				Circle()
					.fill(iconColor.opacity(0.1))
					.frame(width: 40, height: 40)
				Image(systemName: icon)
					.font(.system(size: 18))
					.foregroundStyle(iconColor)
			}
			
			// Texte
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.scaledFont(size: 15, weight: .bold)
					.foregroundStyle(.primary)
				
				if let value = value {
					Text("\(value, specifier: "%.2f") €")
						.scaledFont(size: 14, weight: .medium)
						.foregroundStyle(.secondary)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(16)
		.background(Color(UIColor.secondarySystemGroupedBackground))
		.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
		.shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
	}
}

// MARK: - Toast Stack View

/// Vue empilant les toasts avec effet de profondeur
struct ToastStackView: View {
	let toasts: [ToastData]
	let onDismiss: (UUID) -> Void
	
	var body: some View {
		VStack(spacing: -30) {
			ForEach(Array(toasts.enumerated()), id: \.element.id) { idx, toast in
				let depth = toasts.count - 1 - idx
				ToastCard(toast: toast, depth: depth, onDismiss: onDismiss)
					.transition(.move(edge: .bottom).combined(with: .opacity))
			}
		}
		.padding(.bottom, 20)
	}
}

// MARK: - Previews

#Preview("Balance Header") {
	BalanceHeaderContent(
		accountName: "Compte Courant",
		totalCurrent: 1234.56,
		percentageChange: 5.2
	)
}

#Preview("Quick Card") {
	QuickCardContent(
		icon: "banknote",
		iconColor: .blue,
		title: "Solde du mois",
		value: -245.50
	)
	.padding()
	.background(Color(UIColor.systemGroupedBackground))
}
