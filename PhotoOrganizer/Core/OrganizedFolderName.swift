//
//  OrganizedFolderName.swift
//  PhotoOrganizer
//

import Foundation

/// Recognises the folders this app creates so it never nests them again.
///
/// Layout: `YYYY-MM-DD/` for photos filed by date, `YYYY-MM-DD/<simulation>/` (e.g. `2026-07-19/acros`,
/// or `2026-07-19/set2` when the simulation is unknown) for bracketed-set members. The older
/// `YYYY-MM-DD-<suffix>` form is still recognised.
struct OrganizedFolderName: Hashable, Sendable {
	/// "YYYY-MM-DD"
	let date: String
	/// Everything after "YYYY-MM-DD-" in the older flat form, or nil.
	let suffix: String?

	var name: String {
		if let suffix { "\(date)-\(suffix)" } else { date }
	}

	/// The N of a "setN" suffix, or nil.
	var setIndex: Int? { suffix.flatMap(Self.setIndex(of:)) }

	/// "set3" → 3; nil for anything else ("set0", "set01", "provia", "Set1").
	static func setIndex(of name: String) -> Int? {
		guard name.hasPrefix("set") else { return nil }
		let digits = name.dropFirst(3)
		guard !digits.isEmpty, digits.allSatisfy(\.isNumber), digits.first != "0" else { return nil }
		return Int(digits)
	}

	/// Parses "2026-07-19" or "2026-07-19-<suffix>"; nil for anything else.
	static func parse(_ name: String) -> OrganizedFolderName? {
		guard name.count >= 10 else { return nil }
		let datePart = String(name.prefix(10))
		guard ExifDate.isDateFolderName(datePart) else { return nil }
		let rest = name.dropFirst(10)
		if rest.isEmpty {
			return OrganizedFolderName(date: datePart, suffix: nil)
		}
		guard rest.hasPrefix("-"), rest.count > 1 else { return nil }
		return OrganizedFolderName(date: datePart, suffix: String(rest.dropFirst()))
	}

	/// Where a dropped folder sits in the organised layout.
	enum Context: Hashable, Sendable {
		/// The folder *is* the date folder ("…/2026-07-19"): photos of that date may still be split into simulation subfolders.
		case dateFolder(String)
		/// The folder is inside a date folder ("…/2026-07-19/acros", or the older "…/2026-07-19-acros"): photos of that date are home.
		case insideDateFolder(String)
	}

	static func context(of folder: URL) -> Context? {
		if let parsed = parse(folder.lastPathComponent) {
			return parsed.suffix == nil ? .dateFolder(parsed.date) : .insideDateFolder(parsed.date)
		}
		if let parent = parse(folder.deletingLastPathComponent().lastPathComponent), parent.suffix == nil {
			return .insideDateFolder(parent.date)
		}
		return nil
	}
}
