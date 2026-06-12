//
//  CalculationService.swift
//  Finoria
//
//  Created by Godefroy REYNAUD on 05/02/2026.
//

import Foundation

/// Service responsible for all financial calculations.
/// Takes data as input and returns calculated results.
/// Never modifies source data.
struct CalculationService {
	
	// MARK: - Account Totals
	
	/// Calculates the total of non-potential (validated) transactions
	static func totalNonPotential(transactions: [Transaction]) -> Double {
		transactions
			.filter { !$0.potentiel }
			.map { $0.amount }
			.reduce(0, +)
	}
	
	/// Calculates the total of potential (future) transactions
	static func totalPotential(transactions: [Transaction]) -> Double {
		transactions
			.filter { $0.potentiel }
			.map { $0.amount }
			.reduce(0, +)
	}
	
	// MARK: - Time Groupings
	
	/// Returns distinct years present in validated transactions
	static func availableYears(transactions: [Transaction]) -> [Int] {
		let validatedTransactions = transactions.filter { !$0.potentiel }
		let years = validatedTransactions.compactMap { tx -> Int? in
			guard let date = tx.date else { return nil }
			return Calendar.current.component(.year, from: date)
		}
		return Array(Set(years)).sorted()
	}
	
	/// Calculates the total for a given year
	static func totalForYear(_ year: Int, transactions: [Transaction]) -> Double {
		transactions
			.filter {
				// WHY: Using guard let instead of falling back to Date() prevents masking missing date bugs.
				guard !$0.potentiel, let date = $0.date else {
					if !$0.potentiel { print("[WARN] Validated transaction missing date: \($0.id)") }
					return false
				}
				return Calendar.current.component(.year, from: date) == year
			}
			.map { $0.amount }
			.reduce(0, +)
	}
	
	/// Calculates the total for a given month and year
	static func totalForMonth(_ month: Int, year: Int, transactions: [Transaction]) -> Double {
		transactions
			.filter {
				guard !$0.potentiel, let date = $0.date else { return false }
				let components = Calendar.current.dateComponents([.year, .month], from: date)
				return components.year == year && components.month == month
			}
			.map { $0.amount }
			.reduce(0, +)
	}
	
	// MARK: - Percentages
	
	/// Calculates the percentage change between current month and previous month
	/// - Parameter transactions: List of transactions to analyze
	/// - Returns: The percentage change, or nil if not enough data
	static func monthlyChangePercentage(transactions: [Transaction]) -> Double? {
		let calendar = Calendar.current
		let now = Date()
		
		let currentMonth = calendar.component(.month, from: now)
		let currentYear = calendar.component(.year, from: now)
		
		// Calculate previous month
		let previousMonth: Int
		let previousYear: Int
		if currentMonth == 1 {
			previousMonth = 12
			previousYear = currentYear - 1
		} else {
			previousMonth = currentMonth - 1
			previousYear = currentYear
		}
		
		let currentTotal = totalForMonth(currentMonth, year: currentYear, transactions: transactions)
		let previousTotal = totalForMonth(previousMonth, year: previousYear, transactions: transactions)
		
		// If previous month is 0, we can't calculate a percentage
		guard previousTotal != 0 else { return nil }
		return ((currentTotal - previousTotal) / abs(previousTotal)) * 100
	}
	
	// MARK: - Transaction Filters
	
	/// Returns all potential transactions
	static func potentialTransactions(from transactions: [Transaction]) -> [Transaction] {
		transactions.filter { $0.potentiel }
	}
	
	/// Returns all validated transactions, optionally filtered by year and/or month
	static func validatedTransactions(
		from transactions: [Transaction],
		year: Int? = nil,
		month: Int? = nil
	) -> [Transaction] {
		var result = transactions.filter { !$0.potentiel }
		
		if let year = year {
			result = result.filter {
				// WHY: Replaced date ?? Date() fallback with safe optional binding and warning log.
				guard let date = $0.date else {
					print("[WARN] Validated transaction missing date: \($0.id)")
					return false
				}
				return Calendar.current.component(.year, from: date) == year
			}
		}
		
		if let month = month {
			result = result.filter {
				// WHY: Replaced date ?? Date() fallback with safe optional binding and warning log.
				guard let date = $0.date else {
					print("[WARN] Validated transaction missing date: \($0.id)")
					return false
				}
				return Calendar.current.component(.month, from: date) == month
			}
		}
		
		return result
	}
}
