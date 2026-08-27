//
//  ExifDateReader.swift
//  PhotoOrganizer
//

import Foundation
import ImageIO

/// Reads the "date taken" from an image file's metadata with ImageIO.
///
/// Stateless and safe to call from many tasks at once. Only the metadata
/// headers are read (no pixel decoding), so a call costs a few milliseconds
/// even for a 40 MB HEIF.
enum ExifDateReader {
	/// The camera-recorded date, or nil if the file has none or isn't a
	/// readable image. Never throws: an unreadable file is simply "no date".
	static func read(_ url: URL) -> ExifDate? {
		let options: [CFString: Any] = [
			kCGImageSourceShouldCache: false,
			kCGImageSourceShouldCacheImmediately: false,
		]
		guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
			  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [CFString: Any]
		else { return nil }

		let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
		let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]

		// Preference order: when the shutter fired, when the file was digitized,
		// then the generic TIFF timestamp (usually identical on cameras).
		let candidates: [String?] = [
			exif?[kCGImagePropertyExifDateTimeOriginal] as? String,
			exif?[kCGImagePropertyExifDateTimeDigitized] as? String,
			tiff?[kCGImagePropertyTIFFDateTime] as? String,
		]
		for case let candidate? in candidates {
			if let date = ExifDate(exifString: candidate) { return date }
		}
		return nil
	}
}
