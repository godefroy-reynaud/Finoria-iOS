//
//  TransactionCategoryPicker.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import SwiftUI
import UIKit

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
	// Identité de la tuile dont le menu (popover) est ouvert via un appui long.
	@State private var menuItemId: String?

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

	var body: some View {
		VStack(spacing: 4) {
			// Pagination native via TabView `.page` : défilement physique entre
			// les pages de catégories. L'appui long des tuiles (LongPressGesture)
			// cohabite avec le geste de pagination.
			TabView(selection: $currentPage) {
				ForEach(0..<totalPages, id: \.self) { page in
					pageView(items: itemsForPage(page))
						.tag(page)
				}
			}
			.tabViewStyle(.page(indexDisplayMode: .never))
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
		// ForEach sur l'identité stable des items (et non sur l'index) pour que
		// chaque tuile garde son propre popover/gesture de façon fiable.
		LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 16) {
			ForEach(items) { item in
				categoryTile(item)
			}
		}
		.padding(.horizontal, 4)
		// Petit padding en haut pour que l'anneau de sélection de la première
		// ligne ne soit pas rogné par le bord de la page, tout en gardant les
		// lignes alignées en haut (une page à une seule ligne reste en haut).
		.padding(.top, 4)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	}

	/// Une tuile de catégorie : un appui sélectionne, un appui long ouvre un
	/// `popover` ancré sur la tuile pressée. On utilise un `LongPressGesture`
	/// (et non un `contextMenu`) car ce dernier ne se déclenche pas de façon
	/// fiable dans une `List`/`Form` (bug SwiftUI : surligne toute la section).
	/// Le `popover` est ancré à la vue à laquelle il est attaché → il s'affiche
	/// au bon endroit, au-dessus de la catégorie concernée.
	@ViewBuilder
	private func categoryTile(_ item: CategoryPickerItem) -> some View {
		let tile = TransactionCategoryTileView(item: item, isSelected: isItemSelected(item))
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

		switch item.kind {
		case .custom, .builtIn:
			tile.popover(isPresented: popoverBinding(for: item)) {
				categoryMenu(for: item)
			}
		case .addButton:
			tile
		}
	}

	/// Binding `isPresented` propre à chaque tuile : vrai uniquement pour la
	/// tuile dont l'identité correspond à `menuItemId`.
	private func popoverBinding(for item: CategoryPickerItem) -> Binding<Bool> {
		Binding(
			get: { menuItemId == item.id },
			set: { if !$0 { menuItemId = nil } }
		)
	}

	/// Contenu du menu présenté en popover. `.presentationCompactAdaptation(.popover)`
	/// force une vraie bulle ancrée (avec flèche) plutôt qu'une feuille sur iPhone.
	@ViewBuilder
	private func categoryMenu(for item: CategoryPickerItem) -> some View {
		Group {
			switch item.kind {
			case let .custom(id, _, _, _):
				if let category = customCategoryById[id] {
					VStack(alignment: .leading, spacing: 18) {
						Button {
							// On ferme le popover PUIS on présente la sheet au tick
							// suivant : éviter deux présentations simultanées (sinon
							// la sheet ne s'affiche pas).
							menuItemId = nil
							DispatchQueue.main.async {
								sheetContext = CategorySheetContext(category: category)
							}
						} label: {
							Label("Modifier", systemImage: "pencil")
						}
						Button(role: .destructive) {
							menuItemId = nil
							DispatchQueue.main.async {
								categoryPendingDeletion = category
								showingDeleteCategoryAlert = true
							}
						} label: {
							Label("Supprimer", systemImage: "trash")
						}
					}
					.padding(.horizontal, 20)
					.padding(.vertical, 16)
				}
			case .builtIn:
				Label("Non modifiable", systemImage: "lock.fill")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.padding()
					.frame(maxWidth: 260)
			case .addButton:
				EmptyView()
			}
		}
		.presentationCompactAdaptation(.popover)
	}

	private func handleLongPress(_ item: CategoryPickerItem) {
		switch item.kind {
		case .builtIn, .custom:
			UIImpactFeedbackGenerator(style: .medium).impactOccurred()
			menuItemId = item.id
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

// MARK: - Sous-vues & modèles privés du picker

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
