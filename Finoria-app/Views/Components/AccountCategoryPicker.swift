//
//  AccountCategoryPicker.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import SwiftUI

// MARK: - Vue réutilisable pour sélectionner un style

/// Grille de sélection de style réutilisable pour tout enum conforme à StylableEnum.
/// Supporte un mode replié (`collapsedRows`) qui n'affiche que les N premières lignes
/// avec un bouton pour déplier et voir toutes les options.
struct AccountCategoryPicker<Style: StylableEnum>: View {
	@Binding var selectedStyle: Style
	let columns: Int
	let collapsedRows: Int?
	var onManualSelection: (() -> Void)? = nil

	@State private var isExpanded = false

	init(selectedStyle: Binding<Style>, columns: Int = 4, collapsedRows: Int? = nil, onManualSelection: (() -> Void)? = nil) {
		self._selectedStyle = selectedStyle
		self.columns = columns
		self.collapsedRows = collapsedRows
		self.onManualSelection = onManualSelection
	}

	private var allItems: [Style] { Array(Style.allCases) }

	private var visibleItems: [Style] {
		guard let collapsedRows, !isExpanded else { return allItems }
		let maxVisible = columns * collapsedRows
		// Always show the selected item in the visible set
		let truncated = Array(allItems.prefix(maxVisible))
		if truncated.contains(where: { $0.id == selectedStyle.id }) {
			return truncated
		}
		// Replace last visible with selectedStyle so it's always visible
		var items = truncated
		if !items.isEmpty {
			items[items.count - 1] = selectedStyle
		}
		return items
	}

	private var needsExpandButton: Bool {
		guard let collapsedRows else { return false }
		return allItems.count > columns * collapsedRows
	}

	var body: some View {
		VStack(spacing: 8) {
			LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 16) {
				ForEach(visibleItems, id: \.id) { style in
					Button {
						selectedStyle = style
						onManualSelection?()
					} label: {
						VStack(spacing: 6) {
							ZStack {
								Circle()
									.fill(style.color.opacity(selectedStyle.id == style.id ? 0.3 : 0.1))
									.frame(width: 52, height: 52)
								Image(systemName: style.icon)
									.font(.system(size: 22))
									.foregroundStyle(style.color)
							}
							.overlay(
								Circle()
									.stroke(style.color, lineWidth: selectedStyle.id == style.id ? 2 : 0)
							)

							Text(style.label)
								.font(.caption2)
								.foregroundStyle(selectedStyle.id == style.id ? style.color : .secondary)
								.lineLimit(1)
						}
					}
					.buttonStyle(PlainButtonStyle())
				}
			}

			if needsExpandButton {
				Button {
					withAnimation(.easeInOut(duration: 0.25)) {
						isExpanded.toggle()
					}
				} label: {
					HStack(spacing: 4) {
						Text(isExpanded ? "Voir moins" : "Voir tout")
							.font(.subheadline.weight(.medium))
						Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
							.font(.caption.weight(.semibold))
					}
					.foregroundStyle(.secondary)
					.padding(.top, 4)
				}
				.buttonStyle(PlainButtonStyle())
			}
		}
		.padding(.vertical, 8)
	}
}
