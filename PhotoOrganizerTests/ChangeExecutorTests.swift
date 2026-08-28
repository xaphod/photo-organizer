//
//  ChangeExecutorTests.swift
//  PhotoOrganizerTests
//

import Foundation
import Testing
import os
@testable import PhotoOrganizer

struct ChangeExecutorTests {
	private let operation = MoveIntoDateFoldersOperation()

	@Test func movesOnlyPlannedRowsAndIsIdempotent() async throws {
		let dir = try TempDir()
		try Fixtures.makeImage(at: dir.file("DSCF0001.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:22:21")
		try Fixtures.makeImage(at: dir.file("DSCF0002.HIF"), type: .heic, dateTimeOriginal: "2026:07:19 23:59:59")
		try Fixtures.makeImage(at: dir.file("DSCF0003.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:20 00:00:01")
		try Fixtures.makeImage(at: dir.file("DSCF0004.JPG"), type: .jpeg, dateTimeOriginal: nil)
		try Fixtures.writeText("notes", at: dir.file("notes.txt"))

		let scan = try await FolderScanner.scan(folder: dir.url)
		let changes = operation.plan(files: scan.files, in: dir.url)
		#expect(changes.filter { $0.status == .move }.count == 3)

		let report = await ChangeExecutor.execute(changes)

		#expect(report.movedCount == 3)
		#expect(report.failures.isEmpty)
		#expect(report.folderCount == 2)
		#expect(report.foldersCreated == ["2026-07-19", "2026-07-20"])
		#expect(try dir.listing() == [
			"2026-07-19",
			"2026-07-19/DSCF0001.JPG",
			"2026-07-19/DSCF0002.HIF",
			"2026-07-20",
			"2026-07-20/DSCF0003.JPG",
			"DSCF0004.JPG",
			"notes.txt",
		])

		// Running again finds nothing left to move and leaves the date folders alone.
		let rescan = try await FolderScanner.scan(folder: dir.url)
		let replanned = operation.plan(files: rescan.files, in: dir.url)
		#expect(rescan.ignoredSubfolders == 2)
		#expect(replanned.map(\.status) == [.noDate, .notAnImage])
		let secondReport = await ChangeExecutor.execute(replanned)
		#expect(secondReport.movedCount == 0 && secondReport.failures.isEmpty)
	}

	@Test func neverOverwritesADestinationCreatedAfterPlanning() async throws {
		let dir = try TempDir()
		try Fixtures.makeImage(at: dir.file("DSCF0001.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:22:21")
		try Fixtures.makeImage(at: dir.file("DSCF0002.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:22:22")
		let scan = try await FolderScanner.scan(folder: dir.url)
		let changes = operation.plan(files: scan.files, in: dir.url)
		#expect(changes.map(\.status) == [.move, .move])

		// Something else creates the destination between planning and Go.
		let sub = try dir.makeSubfolder("2026-07-19")
		let blocker = sub.appendingPathComponent("DSCF0002.JPG")
		try Fixtures.writeText("keep me", at: blocker)

		let report = await ChangeExecutor.execute(changes)

		#expect(report.movedCount == 1)
		#expect(report.failures.count == 1)
		#expect(report.failures.first?.change.name == "DSCF0002.JPG")
		#expect(try String(contentsOf: blocker, encoding: .utf8) == "keep me")
		#expect(FileManager.default.fileExists(atPath: dir.file("DSCF0002.JPG").path))
		#expect(!FileManager.default.fileExists(atPath: dir.file("DSCF0001.JPG").path))
	}

	@Test func filesBracketedSetsIntoSetFolders() async throws {
		let dir = try TempDir()
		for number in 1...3 {
			try Fixtures.makeImage(at: dir.file("DSCF000\(number).HIF"), type: .heic, dateTimeOriginal: "2026:07:19 12:21:42", subsecTimeOriginal: "17")
		}
		for number in 4...6 {
			try Fixtures.makeImage(at: dir.file("DSCF000\(number).HIF"), type: .heic, dateTimeOriginal: "2026:07:19 12:21:53", subsecTimeOriginal: "32")
		}
		try Fixtures.makeImage(at: dir.file("DSCF0007.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:30:00", subsecTimeOriginal: "05")

		let scan = try await FolderScanner.scan(folder: dir.url)
		let plan = operation.plan(files: scan.files, in: dir.url, options: OrganizeOptions(detectBracketSets: true))
		#expect(plan.bracketing?.detectedCount == 3)
		#expect(plan.bracketing?.completeSets == 2)

		let report = await ChangeExecutor.execute(plan.changes)

		#expect(report.movedCount == 7)
		#expect(report.failures.isEmpty)
		#expect(report.folderCount == 4)
		#expect(report.foldersCreated == ["2026-07-19", "2026-07-19/set1", "2026-07-19/set2", "2026-07-19/set3"])
		#expect(try dir.listing() == [
			"2026-07-19",
			"2026-07-19/DSCF0007.JPG",
			"2026-07-19/set1",
			"2026-07-19/set1/DSCF0001.HIF",
			"2026-07-19/set1/DSCF0004.HIF",
			"2026-07-19/set2",
			"2026-07-19/set2/DSCF0002.HIF",
			"2026-07-19/set2/DSCF0005.HIF",
			"2026-07-19/set3",
			"2026-07-19/set3/DSCF0003.HIF",
			"2026-07-19/set3/DSCF0006.HIF",
		])

		let rescan = try await FolderScanner.scan(folder: dir.url)
		#expect(rescan.files.isEmpty)
		#expect(rescan.ignoredSubfolders == 1)
	}

	@Test func reportsProgressUpToTotal() async throws {
		let dir = try TempDir()
		for index in 0..<3 {
			try Fixtures.makeImage(at: dir.file("DSCF000\(index).JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:00:0\(index)")
		}
		let scan = try await FolderScanner.scan(folder: dir.url)
		let changes = operation.plan(files: scan.files, in: dir.url)
		let calls = OSAllocatedUnfairLock<[(Int, Int)]>(initialState: [])

		_ = await ChangeExecutor.execute(changes) { done, total in
			calls.withLock { $0.append((done, total)) }
		}

		let recorded = calls.withLock { $0 }
		#expect(recorded.last?.0 == 3)
		#expect(recorded.last?.1 == 3)
	}
}
