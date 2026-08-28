//
//  ThumbnailLoaderTests.swift
//  PhotoOrganizerTests
//

import Testing
@testable import PhotoOrganizer

struct ThumbnailLoaderTests {
	@Test func loadsATransformedThumbnailWithinTheSizeLimit() async throws {
		let dir = try TempDir()
		let url = dir.file("DSCF0001.JPG")
		// 8×4 landscape pixels tagged with EXIF orientation 6 (rotate 90° CW) → displayed portrait.
		try Fixtures.makeImage(at: url, type: .jpeg, dateTimeOriginal: "2026:07:19 12:21:42", orientation: 6, width: 8, height: 4)

		let image = try #require(await ThumbnailLoader.thumbnail(for: url, maxPixelSize: 128))

		#expect(image.height > image.width)
		#expect(image.width <= 128 && image.height <= 128)
	}

	@Test func respectsMaxPixelSizeForLargeImages() async throws {
		let dir = try TempDir()
		let url = dir.file("big.JPG")
		try Fixtures.makeImage(at: url, type: .jpeg, dateTimeOriginal: nil, width: 600, height: 300)

		let image = try #require(await ThumbnailLoader.thumbnail(for: url, maxPixelSize: 120))

		#expect(image.width == 120)
		#expect(image.height == 60)
	}

	@Test func enlargedPreviewDecodesTheFullImage() async throws {
		let dir = try TempDir()
		let url = dir.file("big.JPG")
		try Fixtures.makeImage(at: url, type: .jpeg, dateTimeOriginal: nil, width: 1200, height: 800)

		let image = try #require(await ThumbnailLoader.thumbnail(for: url, maxPixelSize: 512, fromFullImage: true))

		#expect(image.width == 512)
		#expect(image.height == 341)
	}

	@Test func nonImagesYieldNoThumbnail() async throws {
		let dir = try TempDir()
		let url = dir.file("notes.JPG")
		try Fixtures.writeText("not an image", at: url)
		#expect(await ThumbnailLoader.thumbnail(for: url) == nil)
		#expect(await ThumbnailLoader.thumbnail(for: dir.file("missing.JPG")) == nil)
	}
}
