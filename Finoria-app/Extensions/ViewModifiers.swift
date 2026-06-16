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

// MARK: - Police système redimensionnable (Dynamic Type)

/// Police système qui respecte les réglages de taille de texte d'iOS (Dynamic Type),
/// contrairement à `.font(.system(size:))` dont la taille reste figée.
///
/// WHY: on conserve la taille de base exacte du design (au réglage « Par défaut »
/// le rendu est identique au pixel près), tout en laissant le texte grandir/réduire
/// avec les préférences d'accessibilité. `relativeTo` choisit la courbe de mise à
/// l'échelle : pour un très grand nombre on prend `.largeTitle` (croissance plus
/// douce) afin d'éviter les débordements aux tailles d'accessibilité extrêmes.
private struct ScaledSystemFontModifier: ViewModifier {
	@ScaledMetric private var size: CGFloat
	private let weight: Font.Weight

	init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
		_size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
		self.weight = weight
	}

	func body(content: Content) -> some View {
		content.font(.system(size: size, weight: weight))
	}
}

extension View {
	/// Remplace `.font(.system(size:weight:))` par une police équivalente qui
	/// s'adapte aux réglages de taille de texte (Dynamic Type).
	func scaledFont(
		size: CGFloat,
		weight: Font.Weight = .regular,
		relativeTo textStyle: Font.TextStyle = .body
	) -> some View {
		modifier(ScaledSystemFontModifier(size: size, weight: weight, relativeTo: textStyle))
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
							.accessibilityLabel("Changer de compte")
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

// WHY (FIX I): DateFormatter est coûteux à créer — l'ancien code en créait un
// par en-tête de section À CHAQUE rendu de liste. Instance unique, configuration
// figée (le formatage seul est thread-safe, et ces appels viennent du main thread).
private let dayHeaderFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "fr_FR")
	formatter.dateFormat = "EEEE d MMMM yyyy"
	return formatter
}()

extension Date {
	/// Formate la date pour les en-têtes de section groupées par jour.
	/// "Aujourd'hui", "Hier", ou "Lundi 5 février 2026"
	func dayHeaderFormatted() -> String {
		let calendar = Calendar.current
		if calendar.isDateInToday(self) {
			return "Aujourd'hui"
		} else if calendar.isDateInYesterday(self) {
			return "Hier"
		} else {
			return dayHeaderFormatter.string(from: self).capitalized
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
