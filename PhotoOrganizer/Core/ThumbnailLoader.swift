//
//  ThumbnailLoader.swift
//  PhotoOrganizer
//

import CoreGraphics
import Foundation
import ImageIO

/// Produces preview images. Row thumbnails use the thumbnail embedded in the file (≈15 ms for a
/// 40 MP HEIF); the enlarged preview decodes the full image so it is sharp at 512 px.
enum ThumbnailLoader {
	@concurrent
	static func thumbnail(for url: URL, maxPixelSize: Int = 128, fromFullImage: Bool = false) async -> CGImage? {
		if Task.isCancelled { return nil }
		let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
		guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }
		var options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
			kCGImageSourceShouldCacheImmediately: false,
		]
		if fromFullImage {
			options[kCGImageSourceCreateThumbnailFromImageAlways] = true
		} else {
			options[kCGImageSourceCreateThumbnailFromImageIfAbsent] = true
		}
		return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
	}
}
