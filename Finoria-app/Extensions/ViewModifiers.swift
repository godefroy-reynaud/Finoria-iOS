//
//  ViewModifiers.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 12/02/2026.
//

import SwiftUI

// MARK: - Fond adaptatif (Dark/Light)

/// Applique un fond qui s'adapte au mode sombre (noir) et clair (systemGroupedBackground)
struct AdaptiveGroupedBackground: ViewModifier {
	func body(content: Content) -> some View {
		content.background(
			Color(UIColor { traitCollection in
				traitCollection.userInterfaceStyle == .dark ? .black : .systemGroupedBackground
			})
			.ignoresSafeArea()
		)
	}
}

extension View {
	/// Applique le fond adaptatif standard de l'application
	func adaptiveGroupedBackground() -> some View {
		modifier(AdaptiveGroupedBackground())
	}
}

// MARK: - Toolbar Account Picker

/// Ajoute le bouton de sélection de compte dans la toolbar + la sheet associée
// WHY: Plus besoin de transmettre accountsManager — AccountPickerView le lit
// directement depuis l'environnement (@Observable + .environment).
struct AccountPickerToolbarModifier: ViewModifier {
	@Binding var isPresented: Bool

	func body(content: Content) -> some View {
		content
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button {
						isPresented = true
					} label: {
						Image(systemName: "person.crop.circle")
							.imageScale(.large)
					}
				}
			}
			.sheet(isPresented: $isPresented) {
				AccountPickerView()
			}
	}
}

extension View {
	/// Ajoute la toolbar avec le bouton de sélection de compte
	func accountPickerToolbar(isPresented: Binding<Bool>) -> some View {
		modifier(AccountPickerToolbarModifier(isPresented: isPresented))
	}
}

// MARK: - Conditional View Modifier

extension View {
	/// Applique un modifier de manière conditionnelle
	@ViewBuilder
	func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
		if condition {
			transform(self)
		} else {
			self
		}
	}
}

// MARK: - Formatage de date pour en-têtes de section

extension Date {
	/// Formate la date pour les en-têtes de section groupées par jour.
	/// "Aujourd'hui", "Hier", ou "Lundi 5 février 2026"
	func dayHeaderFormatted() -> String {
		let calendar = Calendar.current
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "fr_FR")
		
		if calendar.isDateInToday(self) {
			return "Aujourd'hui"
		} else if calendar.isDateInYesterday(self) {
			return "Hier"
		} else {
			formatter.dateFormat = "EEEE d MMMM yyyy"
			return formatter.string(from: self).capitalized
		}
	}
}

// MARK: - Formatage de montant

extension Double {
	/// Formate un montant en euros avec 2 décimales : "1 234,56 €"
	var formattedCurrency: String {
		self.formatted(.currency(code: "EUR"))
	}
}
