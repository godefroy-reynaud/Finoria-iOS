//
//  FutureTabView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 01/01/2026.
//

import SwiftUI

/// Main view for the Future/Potential transactions tab with toolbar
struct FutureTabView: View {
	@Environment(AccountsManager.self) private var accountsManager
	@State private var showingAccountPicker = false

	var body: some View {
		NavigationStack {
			Group {
				if accountsManager.selectedAccount != nil {
					PotentialTransactionsView()
				} else {
					NoAccountView()
				}
			}
			.navigationTitle("Futur")
			.accountPickerToolbar(isPresented: $showingAccountPicker)
		}
	}
}

#Preview {
	FutureTabView()
		.environment(AccountsManager.preview)
}
