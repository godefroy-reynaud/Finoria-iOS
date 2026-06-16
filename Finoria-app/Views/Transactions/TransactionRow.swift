//
//  TransactionRow.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/08/2025.
//

import SwiftUI

struct TransactionRow: View {
	let transaction: Transaction
	
	var body: some View {
		HStack(spacing: 12) {
			// Icône catégorie
			ZStack {
				Circle()
					.fill(transaction.displayCategoryColor.opacity(0.15))
					.frame(width: 36, height: 36)
				Image(systemName: transaction.displayCategoryIcon)
					.font(.system(size: 16))
					.foregroundStyle(transaction.displayCategoryColor)
					.accessibilityLabel(transaction.displayCategoryLabel)
			}
			
			VStack(alignment: .leading) {
				Text(transaction.comment)
					.font(.body)
				if let date = transaction.date {
					Text(date.formatted(date: .abbreviated, time: .omitted))
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			Spacer()
			Text("\(transaction.amount, specifier: "%.2f") €")
				.foregroundStyle(transaction.amount >= 0 ? .green : .red)
		}
	}
}
