//
//  StylableEnum.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import SwiftUI

/// Protocole unifiant les enums qui ont une représentation visuelle (icône, couleur, label)
/// Utilisé par AccountStyle et TransactionCategory pour factoriser le code
///
/// Les vues qui consomment ce protocole vivent dans `Views/Components/`
/// (`AccountCategoryPicker`, `TransactionCategoryPicker`, `StyleIconView`).
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
