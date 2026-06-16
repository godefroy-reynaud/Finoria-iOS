//
//  ShortcutsGridView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import SwiftUI
import UIKit  // Pour le retour haptique

/// Section affichant la grille de raccourcis (widgets) avec possibilité d'ajout
struct ShortcutsGridView: View {
	let shortcuts: [WidgetShortcut]
	let onShortcutTap: (WidgetShortcut) -> Void
	let onShortcutEdit: (WidgetShortcut) -> Void
	let onShortcutDelete: (WidgetShortcut) -> Void
	let onAddTap: () -> Void
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Header avec bouton d'ajout
			ShortcutsHeader(onAddTap: onAddTap)
			
			// Grille de raccourcis
			LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
				ForEach(shortcuts) { shortcut in
					ShortcutCard(
						shortcut: shortcut,
						onTap: { onShortcutTap(shortcut) },
						onEdit: { onShortcutEdit(shortcut) },
						onDelete: { onShortcutDelete(shortcut) }
					)
				}
			}
		}
		.padding(.horizontal, 20)
	}
}

// MARK: - Header

private struct ShortcutsHeader: View {
	let onAddTap: () -> Void
	
	var body: some View {
		HStack {
			Text("Raccourcis")
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

// MARK: - Carte de raccourci

private struct ShortcutCard: View {
	let shortcut: WidgetShortcut
	let onTap: () -> Void
	let onEdit: () -> Void
	let onDelete: () -> Void
	
	var body: some View {
		Button {
			// Feedback haptique
			let feedback = UIImpactFeedbackGenerator(style: .medium)
			feedback.impactOccurred()
			onTap()
		} label: {
			HStack(spacing: 12) {
				// Icône colorée (composant réutilisable)
				ZStack {
					Circle()
						.fill(shortcut.displayCategoryColor.opacity(0.15))
						.frame(width: 40, height: 40)
					Image(systemName: shortcut.displayCategoryIcon)
						.font(.system(size: 18))
						.foregroundStyle(shortcut.displayCategoryColor)
				}
				
				// Texte
				VStack(alignment: .leading, spacing: 2) {
					Text(shortcut.comment)
						.scaledFont(size: 12, weight: .medium)
						.foregroundStyle(.secondary)
						.lineLimit(1)

					HStack(spacing: 2) {
						Text(shortcut.type == .income ? "+" : "−")
							.scaledFont(size: 14, weight: .bold)
							.foregroundStyle(shortcut.type == .income ? .green : .red)
						Text("\(compactAmount(shortcut.amount)) €")
							.scaledFont(size: 14, weight: .bold)
							.foregroundStyle(.primary)
							.lineLimit(1)
							.minimumScaleFactor(0.8)
					}
				}
				
				Spacer(minLength: 1)
			}
			.padding(12)
			.background(Color(UIColor.secondarySystemGroupedBackground))
			.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
			.shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
		}
		.buttonStyle(PlainButtonStyle())
		.contextMenu {
			Button(action: onEdit) {
				Label("Modifier", systemImage: "pencil")
			}
			
			Button(role: .destructive, action: onDelete) {
				Label("Supprimer", systemImage: "trash")
			}
		}
	}
}

#Preview {
	ShortcutsGridView(
		shortcuts: [
			WidgetShortcut(amount: 50, comment: "Courses", type: .expense, category: .shopping),
			WidgetShortcut(amount: 30, comment: "Essence", type: .expense, category: .fuel)
		],
		onShortcutTap: { _ in },
		onShortcutEdit: { _ in },
		onShortcutDelete: { _ in },
		onAddTap: {}
	)
	.padding()
	.background(Color(UIColor.systemGroupedBackground))
}
