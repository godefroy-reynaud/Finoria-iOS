//
//  DayGroupedTransactionSections.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 15/06/2026.
//

import SwiftUI

/// Transactions regroupées par jour : une `Section` par journée (en-tête
/// `dayHeaderFormatted()`), chaque ligne est une `TransactionRow` avec appui
/// pour éditer et balayage pour supprimer.
///
/// À placer **directement dans un `List`** : la vue produit des `Section`.
/// Le regroupement passe par `groupedByDay()` — fournissez un tableau déjà
/// trié (date décroissante) pour conserver l'ordre intra-jour.
///
/// Factorise le rendu jadis dupliqué entre `AllTransactionsView` et
/// `CategoryTransactionsView`.
struct DayGroupedTransactionSections: View {
	@Environment(AccountsManager.self) private var accountsManager
	let transactions: [Transaction]
	/// Appelé quand une ligne est tapée (l'appelant présente la feuille d'édition).
	let onEdit: (Transaction) -> Void

	var body: some View {
		ForEach(transactions.groupedByDay(), id: \.date) { group in
			Section {
				ForEach(group.transactions) { transaction in
					TransactionRow(transaction: transaction)
						.contentShape(Rectangle())
						.onTapGesture {
							onEdit(transaction)
						}
						.swipeActions(edge: .trailing, allowsFullSwipe: true) {
							Button(role: .destructive) {
								withAnimation {
									accountsManager.deleteTransaction(transaction)
								}
							} label: {
								Label("Supprimer", systemImage: "trash")
							}
						}
				}
			} header: {
				Text(group.date.dayHeaderFormatted())
					.font(.subheadline)
					.fontWeight(.semibold)
					.foregroundStyle(.secondary)
			}
		}
	}
}
