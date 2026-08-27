//
//  ExifDateReaderTests.swift
//  PhotoOrganizerTests
//

import Testing
import UniformTypeIdentifiers
@testable import PhotoOrganizer

struct ExifDateReaderTests {
	@Test func readsDateFromJPEG() throws {
		let dir = try TempDir()
		let url = dir.file("DSCF0001.JPG")
		try Fixtures.makeImage(at: url, type: .jpeg, dateTimeOriginal: "2026:07:19 12:22:21")
		#expect(ExifDateReader.read(url)?.displayString == "2026-07-19 12:22:21")
	}

	@Test func readsDateFromHEICNamedHIF() throws {
		let dir = try TempDir()
		let url = dir.file("DSCF0002.HIF")
		try Fixtures.makeImage(at: url, type: .heic, dateTimeOriginal: "2026:06:19 10:38:11")
		#expect(ExifDateReader.read(url)?.displayString == "2026-06-19 10:38:11")
	}

	@Test func imageWithoutExifHasNoDate() throws {
		let dir = try TempDir()
		let url = dir.file("DSCF0003.JPG")
		try Fixtures.makeImage(at: url, type: .jpeg, dateTimeOriginal: nil)
		#expect(ExifDateReader.read(url) == nil)
	}

	@Test func nonImageNamedLikeAnImageHasNoDate() throws {
		let dir = try TempDir()
		let url = dir.file("fake.JPG")
		try Fixtures.writeText("definitely not a JPEG", at: url)
		#expect(ExifDateReader.read(url) == nil)
	}

	@Test func missingFileHasNoDate() throws {
		let dir = try TempDir()
		#expect(ExifDateReader.read(dir.file("nope.JPG")) == nil)
	}
}
