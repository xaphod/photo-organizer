//
//  ImageMetadata.swift
//  PhotoOrganizer
//

import Foundation

/// Everything the scanner learns about an image in one ImageIO pass.
struct ImageMetadata: Hashable, Sendable {
	/// Camera-local date taken, or nil if the file has no EXIF date.
	var dateTaken: ExifDate?
	/// EXIF SubsecTimeOriginal as written (e.g. "17"). Files of one shutter press share it.
	var subsecond: String?
	/// Fuji film simulation, when ImageIO exposes it.
	var filmSimulation: FilmSimulation?

	init(dateTaken: ExifDate? = nil, subsecond: String? = nil, filmSimulation: FilmSimulation? = nil) {
		self.dateTaken = dateTaken
		self.subsecond = subsecond
		self.filmSimulation = filmSimulation
	}

	/// Parses the dictionary returned by `CGImageSourceCopyPropertiesAtIndex` (bridged to `String` keys).
	init(properties: [String: Any]) {
		let exif = properties["{Exif}"] as? [String: Any]
		let tiff = properties["{TIFF}"] as? [String: Any]

		// Preference order: when the shutter fired, when the file was digitized, then the TIFF timestamp.
		dateTaken = [exif?["DateTimeOriginal"], exif?["DateTimeDigitized"], tiff?["DateTime"]]
			.lazy
			.compactMap { $0 as? String }
			.compactMap(ExifDate.init(exifString:))
			.first

		subsecond = [exif?["SubsecTimeOriginal"], exif?["SubsecTimeDigitized"], exif?["SubsecTime"]]
			.lazy
			.compactMap(Self.string)
			.map { $0.trimmingCharacters(in: .whitespaces) }
			.first { !$0.isEmpty }

		filmSimulation = FilmSimulation(pictureStyle: properties["{PictureStyle}"] as? [String: Any])
	}

	private static func string(_ value: Any?) -> String? {
		switch value {
		case let string as String: string
		case let number as NSNumber: number.stringValue
		default: nil
		}
	}
}

/// A Fuji film simulation, decoded from ImageIO's undocumented `{PictureStyle}` dictionary.
///
/// ImageIO reports `FilmSimulation = (name, code, code)` for colour simulations and, for monochrome
/// ones, no `FilmSimulation` entry but a `Saturation` code (0x500 = Acros, 0x300 = Monochrome…).
/// Codes follow Fuji's `FilmMode` / `Saturation` maker-note tags.
struct FilmSimulation: Hashable, Sendable {
	/// ImageIO's raw name, e.g. "F0/Standard" or "F1b/Studio Portrait Smooth Skin Tone".
	var rawName: String?
	/// Fuji `FilmMode` code (0x000 Provia, 0x120 Astia, 0x600 Classic Chrome…).
	var filmModeCode: Int?
	/// Fuji `Saturation` code when it denotes a monochrome look (0x300–0x3FF, 0x500–0x5FF).
	var monochromeCode: Int?

	init(rawName: String? = nil, filmModeCode: Int? = nil, monochromeCode: Int? = nil) {
		self.rawName = rawName
		self.filmModeCode = filmModeCode
		self.monochromeCode = monochromeCode
	}

	init?(pictureStyle: [String: Any]?) {
		guard let pictureStyle else { return nil }
		if let entry = pictureStyle["FilmSimulation"] as? [Any], !entry.isEmpty {
			let name = entry.first as? String
			let code = entry.dropFirst().lazy.compactMap(Self.int).first
			guard name != nil || code != nil else { return nil }
			self.init(rawName: name, filmModeCode: code)
			return
		}
		if let entry = pictureStyle["Saturation"] as? [Any],
		   let code = entry.lazy.compactMap(Self.int).first,
		   Self.isMonochromeCode(code) {
			self.init(monochromeCode: code)
			return
		}
		return nil
	}

	/// Friendly name ("Provia", "Astia", "Acros"…), ImageIO's name without its "Fx/" prefix, or nil.
	var displayName: String? {
		if let monochromeCode, let name = Self.monochromeNames[monochromeCode] {
			return name
		}
		if let filmModeCode, let name = Self.filmModeNames[filmModeCode] {
			return name
		}
		if let rawName {
			if let slash = rawName.firstIndex(of: "/") {
				let tail = rawName[rawName.index(after: slash)...].trimmingCharacters(in: .whitespaces)
				if !tail.isEmpty { return tail }
			}
			return rawName
		}
		if let monochromeCode {
			return String(format: "Monochrome 0x%X", monochromeCode)
		}
		return nil
	}

	/// Folder-name form of `displayName`: lower-cased, non-alphanumerics collapsed to "-"
	/// ("Classic Chrome" → "classic-chrome", "Acros+R" → "acros-r"). Nil when the name is unknown.
	var folderSlug: String? {
		guard let displayName else { return nil }
		let slug = displayName
			.lowercased()
			.split { !($0.isLetter || $0.isNumber) }
			.joined(separator: "-")
		return slug.isEmpty ? nil : slug
	}

	static func isMonochromeCode(_ code: Int) -> Bool {
		(0x300...0x3FF).contains(code) || (0x500...0x5FF).contains(code)
	}

	static let filmModeNames: [Int: String] = [
		0x000: "Provia",
		0x100: "Studio Portrait",
		0x110: "Studio Portrait Enh. Sat.",
		0x120: "Astia",
		0x130: "Studio Portrait Sharp",
		0x200: "Velvia",
		0x300: "Studio Portrait Ex",
		0x400: "Velvia",
		0x500: "Pro Neg. Std",
		0x501: "Pro Neg. Hi",
		0x600: "Classic Chrome",
		0x700: "Eterna",
		0x800: "Classic Neg.",
		0x900: "Bleach Bypass",
		0xA00: "Nostalgic Neg.",
		0xB00: "Reala ACE",
	]

	static let monochromeNames: [Int: String] = [
		0x300: "Monochrome",
		0x301: "Monochrome+R",
		0x302: "Monochrome+Ye",
		0x303: "Monochrome+G",
		0x310: "Sepia",
		0x500: "Acros",
		0x501: "Acros+R",
		0x502: "Acros+Ye",
		0x503: "Acros+G",
	]

	private static func int(_ value: Any) -> Int? {
		switch value {
		case let int as Int: int
		case let number as NSNumber: number.intValue
		case let string as String: Int(string)
		default: nil
		}
	}
}
