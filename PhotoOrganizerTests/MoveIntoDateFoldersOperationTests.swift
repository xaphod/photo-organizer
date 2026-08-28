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
	private let detecting = OrganizeOptions(detectBracketSets: true)

	private func photo(_ url: URL, type: UTType = .jpeg, date: String?, subsecond: String? = nil, simulation: FilmSimulation? = nil) -> PhotoFile {
		Fixtures.photo(url, type: type, date: date, subsecond: subsecond, filmSimulation: simulation)
	}

	private let provia = FilmSimulation(rawName: "F0/Standard", filmModeCode: 0x000)
	private let astia = FilmSimulation(rawName: "F1b/Studio Portrait Smooth Skin Tone", filmModeCode: 0x120)
	private let acros = FilmSimulation(monochromeCode: 0x500)

	// MARK: v1 behaviour (default options)

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
		#expect(changes[0].relativeFolder == "2026-07-19")
		#expect(changes[0].destination?.path == dir.file("2026-07-19/DSCF0001.JPG").path)
		#expect(changes[0].dateDisplay == "2026-07-19 12:22:21")
		#expect(changes[0].set == nil)
		#expect(changes[0].setDisplay == "")
		#expect(changes[1].relativeDestination == "2026-07-20/DSCF0002.HIF")
		#expect(changes[2].destination == nil)
		#expect(changes[2].relativeFolder == nil)
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

	@Test func defaultOptionsDoNoBracketDetection() throws {
		let dir = try TempDir()
		let files = (1...3).map { photo(dir.file("DSCF000\($0).HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17") }

		let result = operation.plan(files: files, in: dir.url, options: OrganizeOptions())

		#expect(result.bracketing == nil)
		#expect(result.changes.map(\.relativeDestination) == ["2026-07-19/DSCF0001.HIF", "2026-07-19/DSCF0002.HIF", "2026-07-19/DSCF0003.HIF"])
		#expect(result.changes.allSatisfy { $0.set == nil })
	}

	// MARK: Bracket-set detection

	@Test func filesCompleteSetsIntoFilmSimulationFolders() throws {
		let dir = try TempDir()
		let files = [
			photo(dir.file("DSCF0001.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: provia),
			photo(dir.file("DSCF0002.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: astia),
			photo(dir.file("DSCF0003.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: acros),
			photo(dir.file("DSCF0004.HIF"), type: .heif, date: "2026:07:20 08:00:00", subsecond: "50", simulation: provia),   // single shot
			photo(dir.file("notes.txt"), type: .plainText, date: nil),
		]

		let result = operation.plan(files: files, in: dir.url, options: detecting)

		#expect(result.bracketing?.detectedCount == 3)
		#expect(result.bracketing?.completeSets == 1)
		#expect(result.changes.map(\.status) == [.move, .move, .move, .move, .notAnImage])
		#expect(result.changes.map(\.relativeDestination) == [
			"2026-07-19/provia/DSCF0001.HIF",
			"2026-07-19/astia/DSCF0002.HIF",
			"2026-07-19/acros/DSCF0003.HIF",
			"2026-07-20/DSCF0004.HIF",
			"",
		])
		#expect(result.changes[0].destination?.path == dir.file("2026-07-19/provia/DSCF0001.HIF").path)
		#expect(result.changes.map(\.setDisplay) == ["1 of 3", "2 of 3", "3 of 3", "none", ""])
		#expect(result.changes.map(\.setIndex) == [1, 2, 3, 0, 0])
		#expect(result.changes.map(\.setLabel) == ["provia", "astia", "acros", nil, nil])
		#expect(result.changes[3].set == .unassigned(expectedCount: 3))
		#expect(result.changes[3].explanation.contains("filed by date only"))
		#expect(result.changes[0].explanation.contains("photo 1 of 3"))
		#expect(result.changes[0].explanation.contains("Provia"))
		#expect(result.changes[0].relativeFolder == "2026-07-19/provia")
		#expect(result.changes[3].relativeFolder == "2026-07-20")
		#expect(try dir.listing().isEmpty)
	}

	@Test func fallsBackToSetPositionFoldersWithoutFilmSimulations() throws {
		let dir = try TempDir()
		let files = (1...3).map { photo(dir.file("DSCF000\($0).HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17") }

		let changes = operation.plan(files: files, in: dir.url, options: detecting).changes

		#expect(changes.map(\.relativeDestination) == ["2026-07-19/set1/DSCF0001.HIF", "2026-07-19/set2/DSCF0002.HIF", "2026-07-19/set3/DSCF0003.HIF"])
		#expect(changes.map(\.setLabel) == ["set1", "set2", "set3"])
	}

	@Test func simulationSubfolderOfADateFolderIsInPlaceInBothModes() throws {
		let dir = try TempDir()
		let dated = try dir.makeSubfolder("2026-07-19/acros")
		let files = [
			photo(dated.appendingPathComponent("DSCF0002.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17"),
			photo(dated.appendingPathComponent("DSCF0005.HIF"), type: .heif, date: "2026:07:19 12:21:53", subsecond: "32"),
			photo(dated.appendingPathComponent("DSCF0009.HIF"), type: .heif, date: "2026:07:21 12:21:53", subsecond: "32"),
		]

		let off = operation.plan(files: files, in: dated)
		#expect(off.map(\.status) == [.alreadyInPlace, .alreadyInPlace, .move])
		#expect(off[2].relativeDestination == "2026-07-21/DSCF0009.HIF")

		let on = operation.plan(files: files, in: dated, options: detecting).changes
		#expect(on.map(\.status) == [.alreadyInPlace, .alreadyInPlace, .move])
		#expect(on[2].relativeDestination == "2026-07-21/DSCF0009.HIF")
	}

	@Test func droppedDateFolderIsSplitIntoSimulationSubfolders() throws {
		let dir = try TempDir()
		let dated = try dir.makeSubfolder("2026-07-19")
		let files = [
			photo(dated.appendingPathComponent("DSCF0001.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: provia),
			photo(dated.appendingPathComponent("DSCF0002.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: astia),
			photo(dated.appendingPathComponent("DSCF0003.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: acros),
			photo(dated.appendingPathComponent("DSCF0004.HIF"), type: .heif, date: "2026:07:19 13:00:00", subsecond: "40", simulation: provia),   // single
			photo(dated.appendingPathComponent("DSCF0005.HIF"), type: .heif, date: "2026:07:21 09:00:00", subsecond: "10", simulation: provia),   // other day
		]

		let off = operation.plan(files: files, in: dated)
		#expect(off.map(\.status) == [.alreadyInPlace, .alreadyInPlace, .alreadyInPlace, .alreadyInPlace, .move])

		let on = operation.plan(files: files, in: dated, options: detecting).changes
		#expect(on.map(\.status) == [.move, .move, .move, .alreadyInPlace, .move])
		#expect(on.map(\.relativeDestination) == ["provia/DSCF0001.HIF", "astia/DSCF0002.HIF", "acros/DSCF0003.HIF", "", "2026-07-21/DSCF0005.HIF"])
		#expect(on[0].destination?.path == dated.appendingPathComponent("provia/DSCF0001.HIF").path)
	}

	@Test func legacyFlatSetFolderIsInPlace() throws {
		let dir = try TempDir()
		let legacy = try dir.makeSubfolder("2026-07-19-astia")
		let files = [photo(legacy.appendingPathComponent("DSCF0002.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: astia)]
		#expect(operation.plan(files: files, in: legacy).map(\.status) == [.alreadyInPlace])
		#expect(operation.plan(files: files, in: legacy, options: detecting).changes.map(\.status) == [.alreadyInPlace])
	}

	@Test func existingFileInASetFolderIsNeverOverwritten() throws {
		let dir = try TempDir()
		let proviaFolder = try dir.makeSubfolder("2026-07-19/provia")
		try Fixtures.writeText("original", at: proviaFolder.appendingPathComponent("DSCF0001.HIF"))
		let files = [
			photo(dir.file("DSCF0001.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: provia),
			photo(dir.file("DSCF0002.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: astia),
			photo(dir.file("DSCF0003.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", simulation: acros),
		]

		let changes = operation.plan(files: files, in: dir.url, options: detecting).changes

		#expect(changes.map(\.status) == [.alreadyExists, .move, .move])
		#expect(changes[0].set == .member(index: 1, count: 3, label: "provia"))
	}
}
