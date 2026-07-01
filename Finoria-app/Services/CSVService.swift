//
//  CSVService.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/02/2026.
//

import Foundation

/// Service responsable de l'import et export CSV.
/// Gère la sérialisation/désérialisation des transactions au format CSV (RFC 4180).
struct CSVService {

	// MARK: - Données d'export (Sendable)

	/// Ligne d'export pré-extraite des modèles SwiftData.
	// WHY (FIX E): Les @Model SwiftData ne sont pas Sendable et doivent être lus
	// sur le main actor. Ce snapshot en valeurs simples permet de générer le CSV
	// HORS du main actor, sans geler l'UI pendant la construction du fichier.
	struct ExportRow: Sendable {
		let date: Date?
		let amount: Double
		let comment: String
		let categoryLabel: String
	}

	// MARK: - Export

	/// Génère un fichier CSV à partir d'un snapshot de transactions.
	/// - Parameters:
	///   - rows: Lignes pré-extraites (Sendable — peut s'exécuter hors main actor)
	///   - accountName: Nom du compte (utilisé pour le nom du fichier)
	/// - Returns: URL temporaire du fichier CSV généré, ou nil si erreur
	static func generateCSV(rows: [ExportRow], accountName: String) -> URL? {
		// Tri des transactions par date décroissante
		let sortedRows = rows.sorted { row1, row2 in
			if let date1 = row1.date, let date2 = row2.date {
				return date1 > date2
			} else if row1.date != nil {
				return true
			} else {
				return false
			}
		}

		guard !sortedRows.isEmpty else {
			print("⚠️ Aucune transaction à exporter")
			return nil
		}

		// Construction du CSV
		var csvText = "Date,Montant,Commentaire,Catégorie\n"

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "dd/MM/yyyy"
		dateFormatter.locale = Locale(identifier: "fr_FR")

		for row in sortedRows {
			// WHY: plus de colonne "Type" — le signe du montant porte l'information
			// (dépense = négatif, revenu = positif). Le séparateur décimal est une
			// virgule (format FR) ; comme le montant contient alors une virgule,
			// escapeCSVField l'entoure automatiquement de guillemets pour qu'il
			// reste bien une seule colonne.
			let fields = [
				row.date.map { dateFormatter.string(from: $0) } ?? "N/A",
				String(format: "%.2f", row.amount).replacingOccurrences(of: ".", with: ","),
				row.comment,
				row.categoryLabel
			]
			// WHY (FIX B): échappement RFC 4180 de CHAQUE champ. L'ancien code
			// remplaçait les virgules du commentaire par des points-virgules
			// (perte de données) et n'échappait pas du tout la catégorie —
			// une catégorie personnalisée contenant une virgule créait une
			// colonne fantôme et corrompait toute la ligne.
			csvText += fields.map(escapeCSVField).joined(separator: ",") + "\n"
		}

		// Sauvegarde dans un fichier temporaire
		let fileName = "\(accountName)_transactions_\(Date().timeIntervalSince1970).csv"
		let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

		do {
			try csvText.write(to: tempURL, atomically: true, encoding: .utf8)
			print("✅ CSV généré avec succès: \(tempURL.path)")
			print("📊 \(sortedRows.count) transactions exportées")
			return tempURL
		} catch {
			print("❌ Erreur lors de la génération du CSV: \(error.localizedDescription)")
			return nil
		}
	}

	/// Échappe un champ CSV selon RFC 4180 : entoure de guillemets tout champ
	/// contenant une virgule, un guillemet ou un saut de ligne, et double
	/// les guillemets internes (`"` → `""`).
	private static func escapeCSVField(_ field: String) -> String {
		guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
			return field
		}
		return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
	}

	// MARK: - Import

	/// Parse un fichier CSV et retourne les transactions correspondantes
	/// - Parameter url: URL du fichier CSV à importer
	/// - Returns: Tableau de transactions parsées (vide si erreur ou fichier invalide)
	static func importCSV(from url: URL) -> [Transaction] {
		var importedTransactions: [Transaction] = []

		do {
			// Accès sécurisé au fichier
			guard url.startAccessingSecurityScopedResource() else {
				print("❌ Impossible d'accéder au fichier")
				return []
			}
			defer { url.stopAccessingSecurityScopedResource() }

			let content = try String(contentsOf: url, encoding: .utf8)
			let lines = content.components(separatedBy: .newlines)

			// WHY (FIX I): formatter créé UNE seule fois par import —
			// l'ancien code en créait un par ligne (coûteux sur de gros fichiers).
			let dateFormatter = DateFormatter()
			dateFormatter.dateFormat = "dd/MM/yyyy"
			dateFormatter.locale = Locale(identifier: "fr_FR")

			for line in lines.dropFirst() {
				let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
				guard !trimmedLine.isEmpty else { continue }

				// WHY (FIX B): parsing avec gestion des champs entre guillemets
				// (RFC 4180) au lieu d'un split naïf sur la virgule, qui coupait
				// au milieu des champs échappés.
				let columns = parseCSVLine(trimmedLine)
				guard columns.count >= 3 else {
					print("⚠️ Ligne invalide (colonnes insuffisantes): \(line)")
					continue
				}

				// Parse Date
				let dateString = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
				let date: Date?
				if dateString == "N/A" {
					date = nil
				} else {
					date = dateFormatter.date(from: dateString)
				}

				// Parse Montant — séparateur décimal virgule (format FR) et signe
				// porteur du sens : négatif = dépense, positif = revenu. Plus de
				// colonne "Type", le signe suffit.
				let montantString = columns[1]
					.trimmingCharacters(in: .whitespacesAndNewlines)
					.replacingOccurrences(of: ",", with: ".")
				guard let amount = Double(montantString) else {
					print("⚠️ Montant invalide: \(montantString)")
					continue
				}

				// Parse Commentaire (les virgules sont préservées grâce aux guillemets RFC 4180)
				let comment = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)

				// Parse Catégorie (colonne 4 si présente, sinon .other)
				var category: TransactionCategory = .other
				var importedCategoryName: String? = nil
				if columns.count >= 4 {
					let categoryLabel = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
					if let matched = TransactionCategory.allCases.first(where: { $0.label == categoryLabel }) {
						category = matched
					} else if !categoryLabel.isEmpty {
						// Catégorie inconnue dans le compte actuel: fallback "Autre" + mémorisation du libellé CSV
						importedCategoryName = categoryLabel
					}
				}

				let transaction = Transaction(
					amount: amount,
					comment: comment,
					potentiel: false,
					date: date ?? Date(),
					category: category,
					importedCategoryName: importedCategoryName
				)

				importedTransactions.append(transaction)
				print("✅ Transaction parsée: \(comment) - \(amount)€")
			}

			print("📊 Import terminé: \(importedTransactions.count) transactions parsées")

		} catch {
			print("❌ Erreur lors de l'import CSV: \(error.localizedDescription)")
		}

		return importedTransactions
	}

	/// Découpe une ligne CSV en champs en respectant les guillemets RFC 4180.
	/// Gère les champs entre guillemets contenant des virgules et les guillemets
	/// doublés (`""` → `"`).
	private static func parseCSVLine(_ line: String) -> [String] {
		var fields: [String] = []
		var currentField = ""
		var isInsideQuotes = false

		let characters = Array(line)
		var index = 0
		while index < characters.count {
			let character = characters[index]
			if isInsideQuotes {
				if character == "\"" {
					if index + 1 < characters.count && characters[index + 1] == "\"" {
						// Guillemet doublé à l'intérieur d'un champ → guillemet littéral
						currentField.append("\"")
						index += 1
					} else {
						isInsideQuotes = false
					}
				} else {
					currentField.append(character)
				}
			} else {
				switch character {
				case "\"":
					isInsideQuotes = true
				case ",":
					fields.append(currentField)
					currentField = ""
				default:
					currentField.append(character)
				}
			}
			index += 1
		}
		fields.append(currentField)
		return fields
	}
}
