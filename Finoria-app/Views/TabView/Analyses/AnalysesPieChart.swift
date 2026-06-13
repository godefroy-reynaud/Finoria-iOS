//
//  AnalysesPieChart.swift
//  Finoria
//

import SwiftUI
import Charts

/// Graphique camembert interactif affichant la répartition par catégorie.
///
/// Le tap sur une tranche la sélectionne ; un tap au centre ou à l'extérieur désélectionne.
struct AnalysesPieChart: View {
	let chartData: [CategoryData]
	let categoryData: [CategoryData]
	let total: Double
	let displayTotal: Double
	let analysisType: AnalysisType
	@Binding var selectedSlice: String?
	
	// MARK: - Body
	
	var body: some View {
		Chart(chartData) { item in
			SectorMark(
				angle: .value("Montant", item.total),
				innerRadius: .ratio(0.6),
				angularInset: 1.5
			)
			.foregroundStyle(item.color)
			.opacity(selectedSlice == nil || selectedSlice == item.id ? 1 : 0.4)
		}
		.chartBackground { _ in
			VStack(spacing: 2) {
				if let selected = selectedSlice,
				   let data = categoryData.first(where: { $0.id == selected }) {
					CategoryIconView(icon: data.icon, color: data.color, size: 28)
					Text(data.total, format: .currency(code: "EUR"))
						.font(.title3.weight(.bold))
						.minimumScaleFactor(0.6)
					Text(data.label)
						.font(.caption)
						.foregroundStyle(.secondary)
				} else {
					Text(total, format: .currency(code: "EUR"))
						.font(.title2.weight(.bold))
						.minimumScaleFactor(0.6)
					Text(analysisType == .expenses ? "dépensés" : "gagnés")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		}
		.frame(height: 240)
		.chartOverlay { _ in
			GeometryReader { geometry in
				Rectangle().fill(.clear).contentShape(Rectangle())
					.onTapGesture { location in
						handleChartTap(at: location, in: geometry.size)
					}
			}
		}
	}
	
	// MARK: - Interaction
	
	/// Sélectionne la tranche tapée sur l'anneau, désélectionne sinon
	private func handleChartTap(at location: CGPoint, in size: CGSize) {
		let center = CGPoint(x: size.width / 2, y: size.height / 2)
		let dx = location.x - center.x
		let dy = location.y - center.y
		let distance = sqrt(dx * dx + dy * dy)
		let outerRadius = min(size.width, size.height) / 2
		let innerRadius = outerRadius * 0.6
		
		guard distance >= innerRadius && distance <= outerRadius else {
			withAnimation(.easeInOut(duration: 0.2)) {
				selectedSlice = nil
			}
			return
		}
		
		var angle = atan2(dx, -dy)
		if angle < 0 { angle += 2 * .pi }
		let fraction = angle / (2 * .pi)
		let angleValue = fraction * displayTotal
		
		let found = findCategory(for: angleValue)
		withAnimation(.easeInOut(duration: 0.2)) {
			selectedSlice = (selectedSlice == found) ? nil : found
		}
	}
	
	/// Trouve la catégorie (sa clé) correspondant à une valeur cumulée dans le graphique
	private func findCategory(for value: Double) -> String? {
		var cumulative: Double = 0
		for item in chartData {
			cumulative += item.total
			if value <= cumulative {
				return item.id
			}
		}
		return nil
	}
}
