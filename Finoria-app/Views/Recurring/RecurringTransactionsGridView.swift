//
//  RecurringTransactionsGridView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 10/02/2026.
//

import SwiftUI
import UIKit  // Pour le retour haptique

/// Section affichant la grille de transactions récurrentes avec possibilité d'ajout
struct RecurringTransactionsGridView: View {
	let recurringTransactions: [RecurringTransaction]
	let onEdit: (RecurringTransaction) -> Void
	let onDelete: (RecurringTransaction) -> Void
	let onPause: (RecurringTransaction) -> Void
	let onResume: (RecurringTransaction) -> Void
	let onAddTap: () -> Void
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Header avec bouton d'ajout
			RecurringHeader(onAddTap: onAddTap)
			
			// Grille de récurrences
			LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
				ForEach(recurringTransactions) { recurring in
					RecurringCard(
						recurring: recurring,
						onEdit: { onEdit(recurring) },
						onDelete: { onDelete(recurring) },
						onPause: { onPause(recurring) },
						onResume: { onResume(recurring) }
					)
				}
			}
		}
		.padding(.horizontal, 20)
	}
}

// MARK: - Header

private struct RecurringHeader: View {
	let onAddTap: () -> Void
	
	var body: some View {
		HStack {
			Text("Récurrences")
				.scaledFont(size: 18, weight: .bold)
			
			Spacer()
			
			Button(action: onAddTap) {
				HStack(spacing: 4) {
					Image(systemName: "plus")
						.scaledFont(size: 12, weight: .bold)
					Text("Ajouter")
						.scaledFont(size: 11, weight: .bold)
				}
				.foregroundStyle(.blue)
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(Color.blue.opacity(0.1))
				.clipShape(Capsule())
			}
		}
	}
}

// MARK: - Carte de récurrence

private struct RecurringCard: View {
	let recurring: RecurringTransaction
	let onEdit: () -> Void
	let onDelete: () -> Void
	let onPause: () -> Void
	let onResume: () -> Void
	
	var body: some View {
		Button {
			let feedback = UIImpactFeedbackGenerator(style: .medium)
			feedback.impactOccurred()
			onEdit()
		} label: {
			HStack(spacing: 12) {
				// Icône colorée (composant réutilisable)
				ZStack {
					Circle()
						.fill(recurring.displayCategoryColor.opacity(0.15))
						.frame(width: 40, height: 40)
					Image(systemName: recurring.displayCategoryIcon)
						.font(.system(size: 18))
						.foregroundStyle(recurring.displayCategoryColor)
				}
				
				// Texte
				VStack(alignment: .leading, spacing: 2) {
					Text(recurring.comment)
						.scaledFont(size: 12, weight: .medium)
						.foregroundStyle(.secondary)
						.lineLimit(1)

					HStack(spacing: 2) {
						Text(recurring.type == .income ? "+" : "−")
							.scaledFont(size: 14, weight: .bold)
							.foregroundStyle(recurring.type == .income ? .green : .red)
						Text("\(compactAmount(recurring.amount)) €")
							.scaledFont(size: 14, weight: .bold)
							.foregroundStyle(.primary)
							.lineLimit(1)
							.minimumScaleFactor(0.8)
					}
					
					Text(recurring.frequency.shortLabel)
						.scaledFont(size: 10, weight: .medium)
						.foregroundStyle(.tertiary)
				}
				
				Spacer(minLength: 1)
			}
			.padding(12)
			.background(Color(UIColor.secondarySystemGroupedBackground))
			.overlay(alignment: .topTrailing) {
				if recurring.isPaused {
					Button {
						let feedback = UIImpactFeedbackGenerator(style: .light)
						feedback.impactOccurred()
						onResume()
					} label: {
						Image(systemName: "pause.circle.fill")
							.font(.system(size: 22, weight: .medium))
							.foregroundStyle(.white, .gray)
							.shadow(color: .black.opacity(0.15), radius: 3, y: 1)
							.padding(8)
					}
					.buttonStyle(PlainButtonStyle())
				}
			}
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
			.shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
			.saturation(recurring.isPaused ? 0 : 1)
		}
		.buttonStyle(PlainButtonStyle())
		.contextMenu {
			Button(action: onEdit) {
				Label("Modifier", systemImage: "pencil")
			}
			
			if recurring.isPaused {
				Button(action: onResume) {
					Label("Réactiver", systemImage: "play.circle")
				}
			} else {
				Button(action: onPause) {
					Label("Mettre en pause", systemImage: "pause.circle")
				}
			}
			
			Button(role: .destructive, action: onDelete) {
				Label("Supprimer", systemImage: "trash")
			}
		}
	}
}

// MARK: - Preview

#Preview {
	RecurringTransactionsGridView(
		recurringTransactions: [
			RecurringTransaction(amount: 750, comment: "Loyer", type: .expense, category: .rent, frequency: .monthly),
			RecurringTransaction(amount: 2500, comment: "Salaire", type: .income, category: .salary, frequency: .monthly, isPaused: true)
		],
		onEdit: { _ in },
		onDelete: { _ in },
		onPause: { _ in },
		onResume: { _ in },
		onAddTap: {}
	)
	.padding()
	.background(Color(UIColor.systemGroupedBackground))
}
