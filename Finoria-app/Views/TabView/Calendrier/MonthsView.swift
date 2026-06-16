//
//  MonthsView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/08/2025.
//

import SwiftUI

struct MonthsView: View {
	@Environment(AccountsManager.self) private var accountsManager
	var year: Int
	@State private var showingAccountPicker = false

	var body: some View {
		if accountsManager.transactions().isEmpty {
			CalendrierTabView()
		} else {
			List {
				// Tri du plus récent (décembre) au plus ancien (janvier)
				ForEach((1...12).reversed(), id: \.self) { month in
					let total = accountsManager.totalForMonth(month, year: year)
					if total != 0 {
						NavigationLink(value: CalendrierRoute.transactions(month: month, year: year)) {
							HStack {
								Text(Date.monthName(month))
								Spacer()
								Text("\(total, specifier: "%.2f") €")
									.foregroundStyle(total >= 0 ? .green : .red)
							}
						}
					}
				}
			}
			.navigationTitle("\(year)")
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						showingAccountPicker = true
					} label: {
						Image(systemName: "person.crop.circle")
							.font(.title2)
							.accessibilityLabel("Changer de compte")
					}
				}
			}
			.sheet(isPresented: $showingAccountPicker) {
				AccountPickerView()
			}
		}
	}
}
