//
//  CalendrierMainView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 01/01/2026.
//

import SwiftUI

/// Vue principale de l'onglet Calendrier avec toolbar
struct CalendrierMainView: View {
	@Environment(AccountsManager.self) private var accountsManager
	@State private var showingAccountPicker = false

	var body: some View {
		NavigationStack {
			Group {
				if accountsManager.selectedAccount != nil {
					CalendrierTabView()
				} else {
					NoAccountView()
						.navigationTitle("Calendrier")
				}
			}
			.accountPickerToolbar(isPresented: $showingAccountPicker)
		}
	}
}

#Preview {
	CalendrierMainView()
		.environment(AccountsManager.preview)
}
