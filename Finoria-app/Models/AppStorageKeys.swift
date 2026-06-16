//
//  AppStorageKeys.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 12/06/2026.
//

import Foundation

/// Clés UserDefaults / @AppStorage centralisées.
///
// WHY: Un enum sans cas sert de namespace : les clés sont définies UNE seule fois.
// Une faute de frappe dans une clé dupliquée provoque un bug silencieux
// (donnée jamais relue) — avec ces constantes, le compilateur attrape l'erreur.
enum AppStorageKeys {
	/// UUID du dernier compte sélectionné (préférence UI, hors CloudKit)
	static let lastSelectedAccountId = "lastSelectedAccountId"

	/// L'utilisateur a vu l'écran de bienvenue au premier lancement
	static let hasSeenWelcome = "hasSeenWelcome"
}
