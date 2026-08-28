//
//  ThumbnailLetterbox.swift
//  PhotoOrganizer
//

import CoreGraphics
import Foundation

/// Removes the black letterbox bars some cameras bake into their embedded thumbnails.
///
/// Fujifilm JPEGs embed a 160×120 preview: the 3:2 picture is letterboxed into a 4:3 frame with
/// black rows, so the row thumbnail shows a band the picture doesn't have. The trimmer compares
/// the thumbnail's aspect ratio with the picture's; the excess along one axis is the most that
/// can be a bar, and only near-black edge rows or columns within that budget are cut. Genuinely
/// dark picture content is never trimmed: without an aspect mismatch nothing is touched.
enum ThumbnailLetterbox {
	/// Mean brightness (0–255) at or below which a row/column counts as a letterbox bar.
	static let barThreshold = 16.0
	/// Relative aspect-ratio mismatch below which there is no letterbox to look for.
	static let tolerance = 0.02

	/// `pictureAspect` is width ÷ height of the picture as stored, i.e. in the same orientation
	/// as `image`.
	static func trimmed(_ image: CGImage, pictureAspect: Double) -> CGImage {
		guard image.width > 0, image.height > 0, pictureAspect > 0 else { return image }
		var box = Box(x: 0, y: 0, width: image.width, height: image.height)
		let aspect = Double(box.width) / Double(box.height)
		guard abs(aspect - pictureAspect) / pictureAspect > tolerance, let pixels = Pixels(image) else { return image }

		if aspect < pictureAspect {
			// Too tall: bars are rows along the top and/or bottom.
			let budget = box.height - Int((Double(box.width) / pictureAspect).rounded())
			trimRows(&box, budget: budget, pixels: pixels)
		} else {
			// Too wide: bars are columns along the left and/or right.
			let budget = box.width - Int((Double(box.height) * pictureAspect).rounded())
			trimColumns(&box, budget: budget, pixels: pixels)
		}
		guard box.width < image.width || box.height < image.height else { return image }
		return image.cropping(to: box.rect) ?? image
	}

	/// Removes up to `budget` bar rows from the top and bottom of the box.
	private static func trimRows(_ box: inout Box, budget: Int, pixels: Pixels) {
		var removed = 0
		while removed < budget, box.height > 1, pixels.rowMean(box.y, in: box) <= barThreshold {
			box.y += 1
			box.height -= 1
			removed += 1
		}
		while removed < budget, box.height > 1, pixels.rowMean(box.y + box.height - 1, in: box) <= barThreshold {
			box.height -= 1
			removed += 1
		}
	}

	/// Removes up to `budget` bar columns from the left and right of the box.
	private static func trimColumns(_ box: inout Box, budget: Int, pixels: Pixels) {
		var removed = 0
		while removed < budget, box.width > 1, pixels.columnMean(box.x, in: box) <= barThreshold {
			box.x += 1
			box.width -= 1
			removed += 1
		}
		while removed < budget, box.width > 1, pixels.columnMean(box.x + box.width - 1, in: box) <= barThreshold {
			box.width -= 1
			removed += 1
		}
	}

	/// A pixel rectangle; `y` counts from the top of the picture.
	struct Box: Equatable {
		var x: Int
		var y: Int
		var width: Int
		var height: Int

		var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
	}

	/// 8-bit greyscale copy of an image; row 0 is the top of the picture.
	struct Pixels {
		let width: Int
		let height: Int
		private let bytes: [UInt8]

		init?(_ image: CGImage) {
			let width = image.width
			let height = image.height
			var bytes = [UInt8](repeating: 0, count: width * height)
			let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
				guard let context = CGContext(
					data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
					bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
					bitmapInfo: CGImageAlphaInfo.none.rawValue
				) else { return false }
				context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
				return true
			}
			guard drawn else { return nil }
			self.width = width
			self.height = height
			self.bytes = bytes
		}

		subscript(x: Int, y: Int) -> UInt8 { bytes[y * width + x] }

		/// Mean brightness of row `y` across the columns of `box`.
		func rowMean(_ y: Int, in box: Box) -> Double {
			var sum = 0
			for x in box.x..<(box.x + box.width) { sum += Int(bytes[y * width + x]) }
			return Double(sum) / Double(box.width)
		}

		/// Mean brightness of column `x` across the rows of `box`.
		func columnMean(_ x: Int, in box: Box) -> Double {
			var sum = 0
			for y in box.y..<(box.y + box.height) { sum += Int(bytes[y * width + x]) }
			return Double(sum) / Double(box.height)
		}

		func rowMean(_ y: Int) -> Double { rowMean(y, in: Box(x: 0, y: 0, width: width, height: height)) }
		func columnMean(_ x: Int) -> Double { columnMean(x, in: Box(x: 0, y: 0, width: width, height: height)) }
	}
}
