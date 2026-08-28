//
//  ImageMetadataReaderTests.swift
//  PhotoOrganizerTests
//

import Testing
import UniformTypeIdentifiers
@testable import PhotoOrganizer

struct ImageMetadataReaderTests {
	@Test func readsDateFromJPEG() throws {
		let dir = try TempDir()
		let url = dir.file("DSCF0001.JPG")
		try Fixtures.makeImage(at: url, type: .jpeg, dateTimeOriginal: "2026:07:19 12:22:21")
		let metadata = ImageMetadataReader.read(url)
		#expect(metadata.dateTaken?.displayString == "2026-07-19 12:22:21")
		#expect(metadata.subsecond == nil)
	}

	@Test func readsDateAndSubsecondFromHEICNamedHIF() throws {
		let dir = try TempDir()
		let url = dir.file("DSCF0002.HIF")
		try Fixtures.makeImage(at: url, type: .heic, dateTimeOriginal: "2026:06:19 10:38:11", subsecTimeOriginal: "17")
		let metadata = ImageMetadataReader.read(url)
		#expect(metadata.dateTaken?.displayString == "2026-06-19 10:38:11")
		#expect(metadata.subsecond == "17")
		#expect(metadata.filmSimulation == nil)
	}

	@Test func imageWithoutExifHasNoDate() throws {
		let dir = try TempDir()
		let url = dir.file("DSCF0003.JPG")
		try Fixtures.makeImage(at: url, type: .jpeg, dateTimeOriginal: nil)
		#expect(ImageMetadataReader.read(url).dateTaken == nil)
	}

	@Test func nonImageNamedLikeAnImageHasNoDate() throws {
		let dir = try TempDir()
		let url = dir.file("fake.JPG")
		try Fixtures.writeText("definitely not a JPEG", at: url)
		#expect(ImageMetadataReader.read(url) == ImageMetadata())
	}

	@Test func missingFileHasNoDate() throws {
		let dir = try TempDir()
		#expect(ImageMetadataReader.read(dir.file("nope.JPG")).dateTaken == nil)
	}
}
