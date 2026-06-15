//
//  StyleIconView.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 06/02/2026.
//

import SwiftUI

// MARK: - Vue icône de style (réutilisable)

/// Affiche une icône de style avec son cercle coloré
struct StyleIconView<Style: StylableEnum>: View {
	let style: Style
	let size: CGFloat

	init(style: Style, size: CGFloat = 40) {
		self.style = style
		self.size = size
	}

	var body: some View {
		ZStack {
			Circle()
				.fill(style.color.opacity(0.15))
				.frame(width: size, height: size)
			Image(systemName: style.icon)
				.font(.system(size: size * 0.45))
				.foregroundStyle(style.color)
		}
	}
}
