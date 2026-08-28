//
//  ImageMetadataReader.swift
//  PhotoOrganizer
//

import Foundation
import ImageIO

/// Reads an image file's metadata (date taken, sub-second, film simulation) with ImageIO.
///
/// Stateless and safe to call from many tasks at once. Only the metadata headers are read
/// (no pixel decoding), so a call costs a few milliseconds even for a 40 MB HEIF.
enum ImageMetadataReader {
	/// Never throws: an unreadable file simply yields empty metadata.
	static func read(_ url: URL) -> ImageMetadata {
		let options: [CFString: Any] = [
			kCGImageSourceShouldCache: false,
			kCGImageSourceShouldCacheImmediately: false,
		]
		guard let source = CGImageSourceCreateWithURL(url as CFURL, options as CFDictionary),
			  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [String: Any]
		else { return ImageMetadata() }
		return ImageMetadata(properties: properties)
	}
}
