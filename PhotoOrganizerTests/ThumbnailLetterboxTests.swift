//
//  ThumbnailLetterboxTests.swift
//  PhotoOrganizerTests
//

import CoreGraphics
import Foundation
import Testing
@testable import PhotoOrganizer

struct ThumbnailLetterboxTests {
	private let content: UInt8 = 90
	private let dark: UInt8 = 30   // dark picture content, above the bar threshold
	private let bar: UInt8 = 10    // a letterbox bar after JPEG ringing: near-black

	/// An 8-bit grey image whose pixel at (x, y) — y counted from the top — is `shade(x, y)`.
	private func image(width: Int, height: Int, shade: (Int, Int) -> UInt8) throws -> CGImage {
		var bytes = [UInt8](repeating: 0, count: width * height)
		for y in 0..<height {
			for x in 0..<width { bytes[y * width + x] = shade(x, y) }
		}
		let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
		return try #require(CGImage(
			width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
			space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
			provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
		))
	}

	private func hasABarOnAnEdge(_ image: CGImage) throws -> Bool {
		let pixels = try #require(ThumbnailLetterbox.Pixels(image))
		let edges = [pixels.rowMean(0), pixels.rowMean(image.height - 1), pixels.columnMean(0), pixels.columnMean(image.width - 1)]
		return edges.contains { $0 <= ThumbnailLetterbox.barThreshold }
	}

	@Test func trimsTheBarsOfAFujifilmJPEGThumbnail() throws {
		// 160×120 EXIF thumbnail scaled to 128 px: a 3:2 picture inside a 4:3 frame,
		// 2 bar rows on top and 8 at the bottom.
		let thumbnail = try image(width: 128, height: 96) { _, y in y < 2 || y >= 88 ? bar : content }

		let trimmed = ThumbnailLetterbox.trimmed(thumbnail, pictureAspect: 1.5)

		#expect(trimmed.width == 128)
		#expect(trimmed.height == 86)
		#expect(try !hasABarOnAnEdge(trimmed))
	}

	@Test func trimsColumnsWhenTheBarsAreVertical() throws {
		let thumbnail = try image(width: 96, height: 128) { x, _ in x < 5 || x >= 92 ? bar : content }

		let trimmed = ThumbnailLetterbox.trimmed(thumbnail, pictureAspect: 2.0 / 3.0)

		#expect(trimmed.width == 87)
		#expect(trimmed.height == 128)
		#expect(try !hasABarOnAnEdge(trimmed))
	}

	@Test func onlyRemovesRowsThatLookLikeBars() throws {
		// A 4:3 frame around a dark 3:2 picture with a 3-row bar: the aspect budget would allow 11.
		let thumbnail = try image(width: 128, height: 96) { _, y in y >= 93 ? bar : dark }

		let trimmed = ThumbnailLetterbox.trimmed(thumbnail, pictureAspect: 1.5)

		#expect(trimmed.height == 93)
	}

	@Test func neverTrimsMoreThanTheAspectMismatchExplains() throws {
		// An all-black 4:3 thumbnail (night shot) loses exactly the 11 rows that can't be picture.
		let thumbnail = try image(width: 128, height: 96) { _, _ in 0 }

		let trimmed = ThumbnailLetterbox.trimmed(thumbnail, pictureAspect: 1.5)

		#expect(trimmed.width == 128)
		#expect(trimmed.height == 85)
	}

	@Test func darkEdgesWithTheRightAspectAreLeftAlone() throws {
		// Right aspect, black bottom rows: that's the picture (or a bar we can't tell apart), keep it.
		let thumbnail = try image(width: 128, height: 85) { _, y in y >= 80 ? 0 : content }

		#expect(ThumbnailLetterbox.trimmed(thumbnail, pictureAspect: 1.5) === thumbnail)
	}

	@Test func ignoresSlightRoundingDifferences() throws {
		// 128×85 is 1.506, not 1.5 — within tolerance, nothing to do.
		let thumbnail = try image(width: 128, height: 85) { _, _ in content }
		#expect(ThumbnailLetterbox.trimmed(thumbnail, pictureAspect: 1.5) === thumbnail)
	}
}
