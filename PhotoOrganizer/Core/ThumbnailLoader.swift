//
//  ThumbnailLoader.swift
//  PhotoOrganizer
//

import CoreGraphics
import Foundation
import ImageIO

/// Produces preview images. Row thumbnails use the thumbnail embedded in the file (≈15 ms for a
/// 40 MP HEIF), with the camera's letterbox bars trimmed and the EXIF orientation applied here;
/// the enlarged preview decodes the full image so it is sharp at 512 px.
enum ThumbnailLoader {
	@concurrent
	static func thumbnail(for url: URL, maxPixelSize: Int = 128, fromFullImage: Bool = false) async -> CGImage? {
		if Task.isCancelled { return nil }
		let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
		guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }
		var options: [CFString: Any] = [
			kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
			kCGImageSourceShouldCacheImmediately: false,
		]
		if fromFullImage {
			// Decoding the picture itself: ImageIO applies the orientation correctly.
			options[kCGImageSourceCreateThumbnailFromImageAlways] = true
			options[kCGImageSourceCreateThumbnailWithTransform] = true
			return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
		}

		// Embedded thumbnail, deliberately *without* ImageIO's transform: for rotated HEIF files
		// (Fujifilm .HIF, macOS 26) ImageIO squeezes the embedded thumbnail into a square and pads
		// the rest of the canvas with black. Take the stored pixels, trim any letterbox bars the
		// camera baked in, then apply the orientation ourselves.
		options[kCGImageSourceCreateThumbnailFromImageIfAbsent] = true
		guard let stored = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
		guard let geometry = pictureGeometry(of: source) else { return stored }
		return ThumbnailLetterbox.trimmed(stored, pictureAspect: geometry.aspect)
			.applyingExifOrientation(geometry.orientation)
	}

	/// The picture's stored width ÷ height (before orientation) and its EXIF orientation.
	private static func pictureGeometry(of source: CGImageSource) -> (aspect: Double, orientation: Int)? {
		let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
		guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options as CFDictionary) as? [String: Any],
		      let width = properties[kCGImagePropertyPixelWidth as String] as? Double,
		      let height = properties[kCGImagePropertyPixelHeight as String] as? Double,
		      width > 0, height > 0
		else { return nil }
		let orientation = properties[kCGImagePropertyOrientation as String] as? Int ?? 1
		return (width / height, orientation)
	}
}
