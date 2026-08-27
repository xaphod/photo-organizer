//
//  ExifDate.swift
//  PhotoOrganizer
//

import Foundation

/// A calendar date and wall-clock time exactly as the camera wrote it in EXIF
/// ("YYYY:MM:DD HH:mm:ss").
///
/// Deliberately *not* a `Date`: "the day a photo was taken" means the camera's
/// local clock, and round-tripping through `Date`/`TimeZone` could push a
/// late-evening shot into the next day.
struct ExifDate: Hashable, Sendable {
	let year: Int
	let month: Int
	let day: Int
	let hour: Int
	let minute: Int
	let second: Int

	init(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) {
		self.year = year
		self.month = month
		self.day = day
		self.hour = hour
		self.minute = minute
		self.second = second
	}

	/// Parses the EXIF "YYYY:MM:DD HH:mm:ss" form. The time part is optional.
	/// Returns nil for blank, all-zero, malformed, or out-of-range values.
	init?(exifString: String) {
		let parts = exifString
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.split(separator: " ", omittingEmptySubsequences: true)
		guard let datePart = parts.first else { return nil }

		let dateFields = datePart.split(separator: ":", omittingEmptySubsequences: false)
		guard dateFields.count == 3,
			  let year = Int(dateFields[0]),
			  let month = Int(dateFields[1]),
			  let day = Int(dateFields[2])
		else { return nil }

		var hour = 0, minute = 0, second = 0
		if parts.count >= 2 {
			let timeFields = parts[1].split(separator: ":", omittingEmptySubsequences: false)
			guard timeFields.count == 3,
				  let h = Int(timeFields[0]),
				  let m = Int(timeFields[1]),
				  let s = Int(timeFields[2])
			else { return nil }
			hour = h; minute = m; second = s
		}

		guard (1...9999).contains(year),
			  (1...12).contains(month),
			  (1...31).contains(day),
			  (0...23).contains(hour),
			  (0...59).contains(minute),
			  (0...60).contains(second)
		else { return nil }

		self.init(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
	}

	/// "YYYY-MM-DD" — the subfolder name the organizer uses.
	var folderName: String {
		String(format: "%04d-%02d-%02d", year, month, day)
	}

	/// "YYYY-MM-DD HH:mm:ss" for display.
	var displayString: String {
		String(format: "%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
	}

	/// True if `name` looks like a folder this app would create, e.g. "2026-07-19".
	static func isDateFolderName(_ name: String) -> Bool {
		let bytes = Array(name.utf8)
		guard bytes.count == 10 else { return false }
		for (index, byte) in bytes.enumerated() {
			if index == 4 || index == 7 {
				if byte != UInt8(ascii: "-") { return false }
			} else if !(UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) {
				return false
			}
		}
		return true
	}
}
