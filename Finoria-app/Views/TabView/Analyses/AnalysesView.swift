//
//  AnalysesView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 12/02/2026.
//

import SwiftUI

// MARK: - Vue principale Analyses

/// Répartition des dépenses ou revenus par catégorie
/// avec graphique camembert et liste détaillée, navigable par mois
struct AnalysesView: View {
	@Environment(AccountsManager.self) private var accountsManager

	@State private var analysisType: AnalysisType = .expenses
	/// Catégorie sélectionnée dans le camembert, identifiée par sa clé de regroupement.
	@State private var selectedSlice: String?

	/// Mois et année actuellement sélectionnés
	@State private var selectedMonth: Int
	@State private var selectedYear: Int
	@State private var showingAddTransactionSheet = false

	/// Mois/année courants (pour limiter la navigation au présent)
	private let currentMonth: Int
	private let currentYear: Int

	init() {
		let now = Date()
		let calendar = Calendar.current
		let m = calendar.component(.month, from: now)
		let y = calendar.component(.year, from: now)
		self.currentMonth = m
		self.currentYear = y
		self._selectedMonth = State(initialValue: m)
		self._selectedYear = State(initialValue: y)
	}
	
	// MARK: - Navigation mensuelle
	
	/// Indique si on peut avancer au mois suivant (pas au-delà du mois courant)
	private var canGoNext: Bool {
		!(selectedMonth == currentMonth && selectedYear == currentYear)
	}
	
	/// Recule d'un mois
	private func goToPreviousMonth() {
		if selectedMonth == 1 {
			selectedMonth = 12
			selectedYear -= 1
		} else {
			selectedMonth -= 1
		}
	}
	
	/// Avance d'un mois (limité au mois courant)
	private func goToNextMonth() {
		guard canGoNext else { return }
		if selectedMonth == 12 {
			selectedMonth = 1
			selectedYear += 1
		} else {
			selectedMonth += 1
		}
	}
	
	// MARK: - Données calculées
	
	private var filteredTransactions: [Transaction] {
		let validated = accountsManager.validatedTransactions(year: selectedYear, month: selectedMonth)
		switch analysisType {
		case .expenses: return validated.filter { $0.amount < 0 }
		case .income:   return validated.filter { $0.amount > 0 }
		}
	}
	
	private var categoryData: [CategoryData] {
		// Regroupe par catégorie effective de la transaction (personnalisée si
		// présente, sinon intégrée) : chaque catégorie personnalisée a désormais
		// sa propre part au lieu d'être fondue dans « Autre ».
		let grouped = Dictionary(grouping: filteredTransactions) { CategoryData.groupKey(for: $0) }
		return grouped.values.map { transactions in
			CategoryData(
				representative: transactions[0],
				total: transactions.reduce(0) { $0 + abs($1.amount) },
				count: transactions.count
			)
		}
		.sorted {
				$0.total == $1.total
					? $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
					: $0.total > $1.total
			}
	}
	
	private var totalAmount: Double {
		categoryData.reduce(0) { $0 + $1.total }
	}
	
	private var chartDisplayData: [CategoryData] {
		guard totalAmount > 0 else { return categoryData }
		let minValue = totalAmount * 0.01
		return categoryData.map {
			CategoryData(representative: $0.representative, total: max($0.total, minValue), count: $0.count)
		}
	}
	
	private var displayTotal: Double {
		chartDisplayData.reduce(0) { $0 + $1.total }
	}
	
	// MARK: - Body
	
	var body: some View {
		List {
			Section {
				segmentedControl
				monthNavigator
			}
			
			if categoryData.isEmpty {
				Section { emptyStateView }
			} else {
				Section {
					AnalysesPieChart(
						chartData: chartDisplayData,
						categoryData: categoryData,
						total: totalAmount,
						displayTotal: displayTotal,
						analysisType: analysisType,
						selectedSlice: $selectedSlice
					)
				}
				
				Section {
					ForEach(categoryData) { item in
						NavigationLink(value: CategoryDetailRoute(category: item.category, customCategoryId: item.customCategoryId, month: selectedMonth, year: selectedYear)) {
							CategoryBreakdownRow(item: item, totalAmount: totalAmount, isSelected: selectedSlice == item.id)
						}
						.listRowBackground(
							selectedSlice == item.id
								? item.color.opacity(0.12)
								: Color(UIColor.secondarySystemGroupedBackground)
						)
					}
				}
			}
		}
		.listStyle(.insetGrouped)
		.onChange(of: analysisType) {
			selectedSlice = nil
		}
		.sheet(isPresented: $showingAddTransactionSheet) {
			AddTransactionView(
				initialTransactionType: analysisType == .income ? .income : .expense
			)
		}
	}
	
	// MARK: - Composants
	
	/// Picker segmenté Dépenses/Revenus
	private var segmentedControl: some View {
		Picker("Type", selection: $analysisType) {
			ForEach(AnalysisType.allCases, id: \.self) { type in
				Text(type.rawValue).tag(type)
			}
		}
		.pickerStyle(.segmented)
	}
	
	/// Navigateur de mois (< Mois Année >) avec boutons chevron
	private var monthNavigator: some View {
		HStack {
			Button {
				withAnimation(.easeInOut(duration: 0.2)) {
					goToPreviousMonth()
					selectedSlice = nil
				}
			} label: {
				Image(systemName: "chevron.left")
					.font(.body.weight(.semibold))
					.foregroundStyle(.blue)
					.frame(width: 44, height: 44)
					.contentShape(Rectangle())
			}
			.buttonStyle(PlainButtonStyle())
			
			Spacer()
			
			Text("\(Date.monthName(selectedMonth)) \(String(selectedYear))")
				.font(.title3.weight(.semibold))
				.contentTransition(.numericText())
			
			Spacer()
			
			Button {
				withAnimation(.easeInOut(duration: 0.2)) {
					goToNextMonth()
					selectedSlice = nil
				}
			} label: {
				Image(systemName: "chevron.right")
					.font(.body.weight(.semibold))
					.foregroundStyle(canGoNext ? .blue : .gray.opacity(0.3))
					.frame(width: 44, height: 44)
					.contentShape(Rectangle())
			}
			.buttonStyle(PlainButtonStyle())
			.disabled(!canGoNext)
		}
	}
	
	/// État vide quand aucune transaction
	private var emptyStateView: some View {
		Button {
			showingAddTransactionSheet = true
		} label: {
			VStack(spacing: 12) {
				Image(systemName: analysisType == .expenses ? "cart" : "banknote")
					.font(.system(size: 48))
					.foregroundStyle(.tertiary)
				Text(analysisType == .expenses ? "Aucune dépense ce mois" : "Aucun revenu ce mois")
					.font(.headline)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 60)
		}
		.buttonStyle(.plain)
	}
	
}

#Preview {
	NavigationStack {
		AnalysesView()
	}
	.environment(AccountsManager.preview)
}
