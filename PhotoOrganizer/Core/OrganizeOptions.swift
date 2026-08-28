//
//  OrganizeOptions.swift
//  PhotoOrganizer
//

import Foundation

/// User-selectable settings that operations may honour.
struct OrganizeOptions: Hashable, Sendable {
	/// Detect film-simulation bracketing sets (photos sharing one capture time) and file
	/// each member into a "YYYY-MM-DD-setN" folder by its position in the set.
	var detectBracketSets = false

	init(detectBracketSets: Bool = false) {
		self.detectBracketSets = detectBracketSets
	}
}
