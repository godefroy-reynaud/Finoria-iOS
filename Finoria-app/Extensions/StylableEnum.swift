//
//  StylableEnum.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import SwiftUI
import UIKit

/// Protocole unifiant les enums qui ont une représentation visuelle (icône, couleur, label)
/// Utilisé par AccountStyle et TransactionCategory pour factoriser le code
protocol StylableEnum: RawRepresentable, CaseIterable, Identifiable, Codable where RawValue == String {
	/// Nom de l'icône SF Symbol
	var icon: String { get }
	/// Couleur associée au style
	var color: Color { get }
	/// Label localisé pour l'affichage
	var label: String { get }
}

// MARK: - Extension par défaut pour Identifiable

extension StylableEnum {
	var id: String { rawValue }
}

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

// MARK: - Paginated Transaction Category Picker Grid

/// Grille paginée de sélection de catégorie de transaction.
/// Étend le comportement existant avec les catégories personnalisées + bouton d'ajout.
struct TransactionCategoryPicker: View {
	@Environment(AccountsManager.self) private var accountsManager
	@Binding var selectedStyle: TransactionCategory
	@Binding var selectedCustomCategoryId: UUID?
	var onManualSelection: (() -> Void)? = nil

	private let columns = 5
	private let rowsPerPage = 2
	private let baseGridHeight: CGFloat = 168
	private let maxCategoryNameLength = 15
	private var itemsPerPage: Int { columns * rowsPerPage }

	@State private var currentPage = 0
	@State private var sheetContext: CategorySheetContext?
	@State private var categoryPendingDeletion: CustomTransactionCategory?
	@State private var showingDeleteCategoryAlert = false
	// Catégorie personnalisée visée par un appui long (pilote la feuille d'actions).
	@State private var pressedCustomCategory: CustomTransactionCategory?
	@State private var showingCustomActions = false
	@State private var showingBuiltInInfoAlert = false

	init(
		selectedStyle: Binding<TransactionCategory>,
		selectedCustomCategoryId: Binding<UUID?> = .constant(nil),
		onManualSelection: (() -> Void)? = nil
	) {
		self._selectedStyle = selectedStyle
		self._selectedCustomCategoryId = selectedCustomCategoryId
		self.onManualSelection = onManualSelection
	}

	private var customCategories: [CustomTransactionCategory] {
		accountsManager.customTransactionCategories()
			.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
	}

	private var customCategoryById: [UUID: CustomTransactionCategory] {
		Dictionary(uniqueKeysWithValues: customCategories.map { ($0.id, $0) })
	}

	private var allItems: [CategoryPickerItem] {
		let builtIns = TransactionCategory.allCases.map { CategoryPickerItem(kind: .builtIn($0)) }
		let customs = customCategories.map {
			CategoryPickerItem(kind: .custom(id: $0.id, name: $0.name, icon: $0.symbol, color: $0.resolvedColor))
		}
		return builtIns + customs + [CategoryPickerItem(kind: .addButton)]
	}

	private var totalPages: Int {
		max(1, (allItems.count + itemsPerPage - 1) / itemsPerPage)
	}

	/// Relie la position de scroll (optionnelle, type natif `scrollPosition`)
	/// à `currentPage`. Permet aussi bien le suivi du défilement utilisateur que
	/// le défilement programmatique (indicateur de page, synchronisation).
	private var scrollPositionBinding: Binding<Int?> {
		Binding(
			get: { currentPage },
			set: { if let newValue = $0 { currentPage = newValue } }
		)
	}

	var body: some View {
		VStack(spacing: 4) {
			// WHY: ScrollView horizontal paginé (API native iOS 17+) plutôt qu'un
			// TabView `.page` — même défilement physique avec accrochage et effet
			// ressort, mais qui laisse passer le `LongPressGesture` des tuiles
			// (le TabView paginé, basé sur UIPageViewController, capte ce geste).
			ScrollView(.horizontal, showsIndicators: false) {
				LazyHStack(spacing: 0) {
					ForEach(0..<totalPages, id: \.self) { page in
						pageView(items: itemsForPage(page))
							.containerRelativeFrame(.horizontal)
							.id(page)
					}
				}
				.scrollTargetLayout()
			}
			.scrollTargetBehavior(.paging)
			.scrollPosition(id: scrollPositionBinding)
			.frame(height: baseGridHeight)

			if totalPages > 1 {
				PageControlIndicator(currentPage: $currentPage, numberOfPages: totalPages)
					.padding(.top, 4)
			}
		}
		.padding(.top, 3)
		.padding(.bottom, 3)
		.alert("Supprimer la catégorie ?", isPresented: $showingDeleteCategoryAlert) {
			Button("Supprimer", role: .destructive) {
				if let category = categoryPendingDeletion {
					deleteCustomCategory(category)
				}
			}
			Button("Annuler", role: .cancel) {
				categoryPendingDeletion = nil
			}
		} message: {
			Text("Suppression définitive.")
		}
		// Feuille d'actions native déclenchée par l'appui long. Le titre reprend
		// le nom de la catégorie pressée : aucune ambiguïté sur la tuile visée.
		.confirmationDialog(
			pressedCustomCategory?.name ?? "Catégorie",
			isPresented: $showingCustomActions,
			titleVisibility: .visible,
			presenting: pressedCustomCategory
		) { category in
			Button("Modifier") {
				sheetContext = CategorySheetContext(category: category)
			}
			Button("Supprimer", role: .destructive) {
				categoryPendingDeletion = category
				showingDeleteCategoryAlert = true
			}
			Button("Annuler", role: .cancel) {}
		}
		.alert("Catégorie d'origine", isPresented: $showingBuiltInInfoAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text("Cette catégorie ne peut pas être modifiée.")
		}
		.sheet(item: $sheetContext) { context in
			AddCustomTransactionCategorySheet(
				title: context.category == nil ? "Nouvelle catégorie" : "Modifier la catégorie",
				initialName: context.category?.name ?? "",
				initialSymbol: context.category?.symbol ?? "tag.fill",
				initialColorHex: context.category?.colorHex ?? "#8E8E93",
				maxNameLength: maxCategoryNameLength,
				onValidateName: { proposedName in
					validateCustomCategoryName(proposedName, editingCategoryId: context.category?.id)
				},
				onSave: { name, symbol, colorHex in
					saveCustomCategory(name: name, symbol: symbol, colorHex: colorHex, editingCategory: context.category)
				}
			)
		}
		.onAppear {
			currentPage = pageIndexForCurrentSelection()
		}
		.onChange(of: selectedStyle) { _, _ in
			syncCurrentPageWithSelection()
		}
		.onChange(of: selectedCustomCategoryId) { _, _ in
			syncCurrentPageWithSelection()
		}
	}

	@ViewBuilder
	private func pageView(items: [CategoryPickerItem]) -> some View {
		LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 16) {
			ForEach(0..<itemsPerPage, id: \.self) { index in
				if index < items.count {
					categoryTile(items[index])
				} else {
					Color.clear
						.frame(width: 52, height: 70)
				}
			}
		}
		.padding(.horizontal, 4)
	}

	/// Une tuile de catégorie : un appui sélectionne, un appui long ouvre la
	/// feuille d'actions (catégorie personnalisée) ou la note « non modifiable »
	/// (catégorie d'origine). Le `LongPressGesture` est `simultaneous` pour
	/// cohabiter avec le défilement du `ScrollView`.
	@ViewBuilder
	private func categoryTile(_ item: CategoryPickerItem) -> some View {
		TransactionCategoryTileView(item: item, isSelected: isItemSelected(item))
			.contentShape(Rectangle())
			.onTapGesture {
				handleTap(item)
			}
			.simultaneousGesture(
				LongPressGesture(minimumDuration: 0.45)
					.onEnded { _ in
						handleLongPress(item)
					}
			)
	}

	private func handleLongPress(_ item: CategoryPickerItem) {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()

		switch item.kind {
		case .builtIn:
			showingBuiltInInfoAlert = true
		case let .custom(id, _, _, _):
			if let customCategory = customCategoryById[id] {
				pressedCustomCategory = customCategory
				showingCustomActions = true
			}
		case .addButton:
			break
		}
	}

	private func handleTap(_ item: CategoryPickerItem) {
		switch item.kind {
		case let .builtIn(category):
			selectedStyle = category
			selectedCustomCategoryId = nil
			onManualSelection?()
		case let .custom(id, _, _, _):
			selectedStyle = .other
			selectedCustomCategoryId = id
			onManualSelection?()
		case .addButton:
			sheetContext = CategorySheetContext(category: nil)
		}
	}

	private func isItemSelected(_ item: CategoryPickerItem) -> Bool {
		switch item.kind {
		case let .builtIn(category):
			return selectedCustomCategoryId == nil && selectedStyle == category
		case let .custom(id, _, _, _):
			return selectedCustomCategoryId == id
		case .addButton:
			return false
		}
	}

	private func itemsForPage(_ page: Int) -> [CategoryPickerItem] {
		let start = page * itemsPerPage
		let end = min(start + itemsPerPage, allItems.count)
		guard start < allItems.count else { return [] }
		return Array(allItems[start..<end])
	}

	private func pageIndexForCurrentSelection() -> Int {
		let index = allItems.firstIndex { item in
			switch item.kind {
			case let .builtIn(category):
				return selectedCustomCategoryId == nil && selectedStyle == category
			case let .custom(id, _, _, _):
				return selectedCustomCategoryId == id
			case .addButton:
				return false
			}
		} ?? 0

		return index / itemsPerPage
	}

	private func syncCurrentPageWithSelection() {
		let targetPage = pageIndexForCurrentSelection()
		guard targetPage != currentPage else { return }
		withAnimation(.easeInOut(duration: 0.2)) {
			currentPage = targetPage
		}
	}

	private func saveCustomCategory(
		name: String,
		symbol: String,
		colorHex: String,
		editingCategory: CustomTransactionCategory?
	) {
		if let editingCategory {
			accountsManager.updateCustomTransactionCategory(
				editingCategory,
				name: name,
				symbol: symbol,
				colorHex: colorHex
			)
			selectedStyle = .other
			selectedCustomCategoryId = editingCategory.id
		} else if let createdCategory = accountsManager.addCustomTransactionCategory(
			name: name,
			symbol: symbol,
			colorHex: colorHex
		) {
			selectedStyle = .other
			selectedCustomCategoryId = createdCategory.id
		}

		onManualSelection?()
	}

	private func deleteCustomCategory(_ category: CustomTransactionCategory) {
		accountsManager.deleteCustomTransactionCategory(category)
		if selectedCustomCategoryId == category.id {
			selectedCustomCategoryId = nil
			selectedStyle = .other
		}
		categoryPendingDeletion = nil
	}

	// WHY (FIX J): copie locale supprimée — utilise l'implémentation canonique
	// AccountsManager.normalizeCategoryName (les deux étaient identiques).
	private func validateCustomCategoryName(_ name: String, editingCategoryId: UUID?) -> String? {
		let normalized = AccountsManager.normalizeCategoryName(name)
		if normalized.isEmpty {
			return "Le nom est obligatoire."
		}

		let builtInNames = Set(TransactionCategory.allCases.map { AccountsManager.normalizeCategoryName($0.label) })
		if builtInNames.contains(normalized) {
			return "Nom déjà utilisé."
		}

		let duplicate = customCategories.contains { customCategory in
			AccountsManager.normalizeCategoryName(customCategory.name) == normalized && customCategory.id != editingCategoryId
		}
		if duplicate {
			return "Nom déjà utilisé."
		}

		return nil
	}
}

private struct CategorySheetContext: Identifiable {
	let id = UUID()
	let category: CustomTransactionCategory?
}

private struct CategoryPickerItem: Identifiable {
	enum Kind {
		case builtIn(TransactionCategory)
		case custom(id: UUID, name: String, icon: String, color: Color)
		case addButton
	}

	let id: String
	let kind: Kind

	init(kind: Kind) {
		self.kind = kind
		switch kind {
		case let .builtIn(category):
			self.id = "builtin-\(category.rawValue)"
		case let .custom(id, _, _, _):
			self.id = "custom-\(id.uuidString)"
		case .addButton:
			self.id = "add-button"
		}
	}

	var label: String {
		switch kind {
		case let .builtIn(category):
			return category.label
		case let .custom(_, name, _, _):
			return name
		case .addButton:
			return "Ajouter"
		}
	}

	var icon: String {
		switch kind {
		case let .builtIn(category):
			return category.icon
		case let .custom(_, _, icon, _):
			return icon
		case .addButton:
			return "plus"
		}
	}

	var color: Color {
		switch kind {
		case let .builtIn(category):
			return category.color
		case let .custom(_, _, _, color):
			return color
		case .addButton:
			return .gray
		}
	}
}

private struct TransactionCategoryTileView: View {
	let item: CategoryPickerItem
	let isSelected: Bool

	var body: some View {
		VStack(spacing: 6) {
			ZStack {
				Circle()
					.fill(item.color.opacity(isSelected ? 0.3 : 0.1))
					.frame(width: 52, height: 52)
				Image(systemName: item.icon)
					.font(.system(size: 22))
					.foregroundStyle(item.color)
			}
			.overlay(
				Circle()
					.stroke(item.color, lineWidth: isSelected ? 2 : 0)
			)

			Text(item.label)
				.font(.caption2)
				.foregroundStyle(isSelected ? item.color : .secondary)
				.lineLimit(1)
		}
	}
}

private struct PageControlIndicator: View {
	@Binding var currentPage: Int
	let numberOfPages: Int
	@Environment(\.colorScheme) private var colorScheme

	private var activeColor: Color {
		Color.primary.opacity(colorScheme == .dark ? 0.95 : 0.8)
	}

	private var inactiveColor: Color {
		Color.primary.opacity(colorScheme == .dark ? 0.4 : 0.24)
	}

	private var containerBackground: Color {
		colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)
	}

	var body: some View {
		HStack(spacing: 9) {
			ForEach(0..<numberOfPages, id: \.self) { index in
				let isActive = index == currentPage
				Circle()
					.fill(isActive ? activeColor : inactiveColor)
					.frame(width: 7, height: 7)
					.scaleEffect(isActive ? 1.12 : 1)
					.animation(.easeInOut(duration: 0.2), value: currentPage)
					.frame(width: 12, height: 12)
					.contentShape(Rectangle())
					.onTapGesture {
						withAnimation(.easeInOut(duration: 0.2)) {
							currentPage = index
						}
					}
					.accessibilityLabel("Page \(index + 1)")
					.accessibilityAddTraits(isActive ? [.isSelected] : [])
			}
		}
		.padding(.horizontal, 9)
		.padding(.vertical, 5)
		.background(containerBackground, in: Capsule(style: .continuous))
		.accessibilityElement(children: .contain)
		.accessibilityLabel("Pages")
	}
}

// MARK: - Vue icône de style (réutilisable)

/// Affiche une icône de style avec son cercle coloré
struct StyleIconView<Style: StylableEnum>: View {
	let style: Style
	let size: CGFloat
	
	init(style: Style, size: CGFloat = 40) {
		self.style = style
		self.size = size
	}
	
	var body: some View {
		ZStack {
			Circle()
				.fill(style.color.opacity(0.15))
				.frame(width: size, height: size)
			Image(systemName: style.icon)
				.font(.system(size: size * 0.45))
				.foregroundStyle(style.color)
		}
	}
}

// MARK: - Formatage compact des montants

/// Formate un montant de manière compacte pour tenir dans un espace restreint.
/// Utilise la locale du système (virgule pour les français, point pour les anglophones, etc.)
/// Réduit progressivement la précision : 2 850,00 € → 2 850 € → 2,85k € → 2,9k € → 3k €
func compactAmount(_ value: Double) -> String {
	let formatter = NumberFormatter()
	formatter.locale = Locale.current
	formatter.numberStyle = .decimal
	formatter.usesGroupingSeparator = false
	
	let thresholds: [(limit: Double, divisor: Double, suffix: String)] = [
		(1_000_000_000, 1_000_000_000, "G"),
		(1_000_000, 1_000_000, "M"),
		(1_000, 1_000, "k")
	]
	
	for t in thresholds where value >= t.limit {
		let reduced = value / t.divisor
		if reduced == reduced.rounded(.down) {
			formatter.minimumFractionDigits = 0
			formatter.maximumFractionDigits = 0
		} else if (reduced * 10).rounded() == (reduced * 10) {
			formatter.minimumFractionDigits = 1
			formatter.maximumFractionDigits = 1
		} else {
			formatter.minimumFractionDigits = 2
			formatter.maximumFractionDigits = 2
		}
		return "\(formatter.string(from: NSNumber(value: reduced)) ?? "\(reduced)")\(t.suffix)"
	}
	
	if value == value.rounded(.down) {
		formatter.minimumFractionDigits = 0
		formatter.maximumFractionDigits = 0
	} else if (value * 10).rounded() == (value * 10) {
		formatter.minimumFractionDigits = 1
		formatter.maximumFractionDigits = 1
	} else {
		formatter.minimumFractionDigits = 2
		formatter.maximumFractionDigits = 2
	}
	return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}
