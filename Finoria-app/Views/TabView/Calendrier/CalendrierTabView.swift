//
//  CalendrierTabView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 14/08/2025.
//

import SwiftUI

enum CalendrierViewMode: String, CaseIterable {
	case jour = "Jour"
	case mois = "Mois"
	case annee = "Année"
}

/// Vue de contenu du calendrier (sans navigation wrapping)
struct CalendrierTabView: View {
	@Environment(AccountsManager.self) private var accountsManager
	@State private var selectedMode: CalendrierViewMode = .jour
	@State private var showingAddTransactionSheet = false
	
	var body: some View {
		VStack(spacing: 0) {
			// Picker en haut
			Picker("Mode", selection: $selectedMode) {
				ForEach(CalendrierViewMode.allCases, id: \.self) { mode in
					Text(mode.rawValue).tag(mode)
				}
			}
			.pickerStyle(.segmented)
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
			
			// Contenu selon le mode sélectionné
			if accountsManager.transactions().isEmpty {
				List {
					Button {
						showingAddTransactionSheet = true
					} label: {
						Text("Aucune transaction")
							.foregroundStyle(.secondary)
							.frame(maxWidth: .infinity)
							.padding(.vertical, 40)
					}
					.buttonStyle(.plain)
				}
			} else {
				switch selectedMode {
				case .jour:
					AllTransactionsView(embedded: true)
				case .mois:
					CalendrierMonthsContentView()
				case .annee:
					CalendrierYearsContentView()
				}
			}
		}
		.adaptiveGroupedBackground()
		.navigationTitle("Calendrier")
		.sheet(isPresented: $showingAddTransactionSheet) {
			AddTransactionView()
		}
		.navigationDestination(for: CalendrierRoute.self) { route in
			switch route {
			case .months(let year):
				MonthsView(year: year)
			case .transactions(let month, let year):
				TransactionsListView(month: month, year: year)
			}
		}
	}
}

// MARK: - Vue Années (contenu uniquement, triées du plus récent au plus ancien)
private struct CalendrierYearsContentView: View {
	@Environment(AccountsManager.self) private var accountsManager
	
	var body: some View {
		List {
			ForEach(accountsManager.availableYears().reversed(), id: \.self) { year in
				NavigationLink(value: CalendrierRoute.months(year: year)) {
					HStack {
						Text("\(year)")
						Spacer()
						Text("\(accountsManager.totalForYear(year), specifier: "%.2f") €")
							.foregroundStyle(accountsManager.totalForYear(year) >= 0 ? .green : .red)
					}
				}
			}
		}
		.scrollContentBackground(.hidden)
	}
}

// MARK: - Vue Mois (contenu uniquement, tous les mois de toutes les années, triés du plus récent)
private struct CalendrierMonthsContentView: View {
	@Environment(AccountsManager.self) private var accountsManager
	
	private var monthsWithData: [(id: String, year: Int, month: Int, total: Double)] {
		var result: [(id: String, year: Int, month: Int, total: Double)] = []
		for year in accountsManager.availableYears().reversed() {
			for month in (1...12).reversed() {
				let total = accountsManager.totalForMonth(month, year: year)
				if total != 0 {
					// ID unique combinant année et mois
					let id = "\(year)-\(month)"
					result.append((id: id, year: year, month: month, total: total))
				}
			}
		}
		return result
	}
	
	var body: some View {
		List {
			ForEach(monthsWithData, id: \.id) { item in
				NavigationLink(value: CalendrierRoute.transactions(month: item.month, year: item.year)) {
					HStack {
						Text("\(Date.monthName(item.month)) \(item.year)")
						Spacer()
						Text("\(item.total, specifier: "%.2f") €")
							.foregroundStyle(item.total >= 0 ? .green : .red)
					}
				}
			}
		}
		.scrollContentBackground(.hidden)
	}
}
