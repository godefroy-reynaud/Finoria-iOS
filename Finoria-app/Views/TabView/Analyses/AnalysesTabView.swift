//
//  AnalysesTabView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 12/02/2026.
//

import SwiftUI

/// Wrapper de l'onglet Analyses avec NavigationStack et toolbar
struct AnalysesTabView: View {
	@Environment(AccountsManager.self) private var accountsManager
	@State private var showingAccountPicker = false

	var body: some View {
		NavigationStack {
			Group {
				if accountsManager.selectedAccount != nil {
					AnalysesView()
						.navigationBarTitleDisplayMode(.large)
						.navigationDestination(for: CategoryDetailRoute.self) { route in
							CategoryTransactionsView(
								category: route.category,
								month: route.month,
								year: route.year
							)
						}
				} else {
					NoAccountView()
				}
			}
			.navigationTitle("Analyses")
			.accountPickerToolbar(isPresented: $showingAccountPicker)
		}
	}
}

#Preview {
	AnalysesTabView()
		.environment(AccountsManager.preview)
}
