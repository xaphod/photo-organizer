//
//  ImageOrientationTests.swift
//  PhotoOrganizerTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PhotoOrganizer

struct ImageOrientationTests {
	/// A 16×8 TIFF whose four quadrants have distinct grey levels, tagged with `orientation`.
	private func makeQuadrantImage(at url: URL, orientation: Int) throws {
		let width = 16, height = 8
		let context = try #require(CGContext(
			data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
		))
		// Core Graphics: y = 0 is the bottom. Top-left 0, top-right 85, bottom-left 170, bottom-right 255.
		for (rect, grey) in [
			(CGRect(x: 0, y: 4, width: 8, height: 4), 0.0),
			(CGRect(x: 8, y: 4, width: 8, height: 4), 85.0 / 255),
			(CGRect(x: 0, y: 0, width: 8, height: 4), 170.0 / 255),
			(CGRect(x: 8, y: 0, width: 8, height: 4), 1.0),
		] {
			context.setFillColor(CGColor(red: grey, green: grey, blue: grey, alpha: 1))
			context.fill(rect)
		}
		let image = try #require(context.makeImage())
		let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.tiff.identifier as CFString, 1, nil))
		CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
		#expect(CGImageDestinationFinalize(destination))
	}

	private func greys(_ image: CGImage) throws -> [UInt8] {
		let pixels = try #require(ThumbnailLetterbox.Pixels(image))
		return (0..<image.height).flatMap { y in (0..<image.width).map { x in pixels[x, y] } }
	}

	/// The embedded-thumbnail path applies the orientation itself; it must land on the same
	/// pixels as ImageIO's own transform of the decoded picture.
	@Test(arguments: 1...8)
	func matchesImageIOForEveryExifOrientation(orientation: Int) async throws {
		let dir = try TempDir()
		let url = dir.file("orientation\(orientation).tiff")
		try makeQuadrantImage(at: url, orientation: orientation)

		let expected = try #require(await ThumbnailLoader.thumbnail(for: url, maxPixelSize: 128, fromFullImage: true))
		let actual = try #require(await ThumbnailLoader.thumbnail(for: url, maxPixelSize: 128))

		#expect(actual.width == expected.width)
		#expect(actual.height == expected.height)
		if orientation >= 5 {
			#expect(actual.width == 8 && actual.height == 16)
		} else {
			#expect(actual.width == 16 && actual.height == 8)
		}
		let expectedGreys = try greys(expected)
		let actualGreys = try greys(actual)
		#expect(expectedGreys.count == actualGreys.count)
		let maxDifference = zip(expectedGreys, actualGreys).map { abs(Int($0) - Int($1)) }.max() ?? 0
		#expect(maxDifference <= 2, "orientation \(orientation): pixels differ by up to \(maxDifference)")
	}

	@Test func leavesUnknownOrientationsAlone() throws {
		let context = try #require(CGContext(
			data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
		))
		let image = try #require(context.makeImage())
		#expect(image.applyingExifOrientation(0) === image)
		#expect(image.applyingExifOrientation(1) === image)
		#expect(image.applyingExifOrientation(9) === image)
	}
}
