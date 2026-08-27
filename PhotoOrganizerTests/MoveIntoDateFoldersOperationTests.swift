//
//  MoveIntoDateFoldersOperationTests.swift
//  PhotoOrganizerTests
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import PhotoOrganizer

struct MoveIntoDateFoldersOperationTests {
	private let operation = MoveIntoDateFoldersOperation()

	private func photo(_ url: URL, type: UTType = .jpeg, date: String?) -> PhotoFile {
		PhotoFile(url: url, contentType: type, exifDate: date.flatMap(ExifDate.init(exifString:)))
	}

	@Test func plansDestinationsFromExifDate() throws {
		let dir = try TempDir()
		let files = [
			photo(dir.file("DSCF0001.JPG"), date: "2026:07:19 12:22:21"),
			photo(dir.file("DSCF0002.HIF"), type: .heif, date: "2026:07:20 01:00:00"),
			photo(dir.file("DSCF0003.JPG"), date: nil),
			photo(dir.file("notes.txt"), type: .plainText, date: nil),
			photo(dir.file("clip.MOV"), type: .quickTimeMovie, date: nil),
		]

		let changes = operation.plan(files: files, in: dir.url)

		#expect(changes.map(\.status) == [.move, .move, .noDate, .notAnImage, .notAnImage])
		#expect(changes[0].relativeDestination == "2026-07-19/DSCF0001.JPG")
		#expect(changes[0].destination?.path == dir.file("2026-07-19/DSCF0001.JPG").path)
		#expect(changes[0].dateDisplay == "2026-07-19 12:22:21")
		#expect(changes[1].relativeDestination == "2026-07-20/DSCF0002.HIF")
		#expect(changes[2].destination == nil)
		#expect(changes[2].relativeDestination == "")
		#expect(changes[2].dateDisplay == "")
		// Planning never touches the disk.
		#expect(try dir.listing().isEmpty)
	}

	@Test func existingDestinationIsNeverOverwritten() throws {
		let dir = try TempDir()
		let sub = try dir.makeSubfolder("2026-07-19")
		try Fixtures.writeText("original", at: sub.appendingPathComponent("DSCF0001.JPG"))
		let files = [
			photo(dir.file("DSCF0001.JPG"), date: "2026:07:19 12:22:21"),
			photo(dir.file("DSCF0002.JPG"), date: "2026:07:19 12:22:22"),
		]

		let changes = operation.plan(files: files, in: dir.url)

		#expect(changes.map(\.status) == [.alreadyExists, .move])
		#expect(changes[0].relativeDestination == "2026-07-19/DSCF0001.JPG")
		#expect(changes[0].explanation.contains("already exists"))
	}

	@Test func namesDifferingOnlyByCaseConflictWithinAPlan() throws {
		let dir = try TempDir()
		let files = [
			photo(dir.file("DSCF0001.JPG"), date: "2026:07:19 12:22:21"),
			photo(dir.file("dscf0001.jpg"), date: "2026:07:19 12:22:21"),
		]

		let changes = operation.plan(files: files, in: dir.url)

		#expect(changes.map(\.status) == [.move, .alreadyExists])
	}

	@Test func folderAlreadyNamedForTheDateIsInPlace() throws {
		let dir = try TempDir()
		let dated = try dir.makeSubfolder("2026-07-19")
		let files = [
			photo(dated.appendingPathComponent("DSCF0001.JPG"), date: "2026:07:19 12:22:21"),
			photo(dated.appendingPathComponent("DSCF0002.JPG"), date: "2026:07:20 09:00:00"),
		]

		let changes = operation.plan(files: files, in: dated)

		#expect(changes.map(\.status) == [.alreadyInPlace, .move])
		#expect(changes[0].destination == nil)
		#expect(changes[1].relativeDestination == "2026-07-20/DSCF0002.JPG")
	}

	@Test func isListedInTheOperationRegistry() {
		#expect(OrganizeOperations.operation(withID: operation.id) != nil)
		#expect(!OrganizeOperations.all.isEmpty)
	}
}
