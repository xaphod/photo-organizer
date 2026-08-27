//
//  FolderScannerTests.swift
//  PhotoOrganizerTests
//

import Foundation
import Testing
import os
@testable import PhotoOrganizer

struct FolderScannerTests {
	@Test func listsOnlyTopLevelRegularFilesSortedByName() async throws {
		let dir = try TempDir()
		try Fixtures.makeImage(at: dir.file("DSCF0002.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:22:21")
		try Fixtures.makeImage(at: dir.file("DSCF0010.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:22:22")
		try Fixtures.makeImage(at: dir.file("DSCF0003.HIF"), type: .heic, dateTimeOriginal: "2026:07:20 08:00:00")
		try Fixtures.writeText("notes", at: dir.file("notes.txt"))
		try Fixtures.writeText("", at: dir.file(".DS_Store"))
		let sub = try dir.makeSubfolder("2026-07-19")
		try Fixtures.makeImage(at: sub.appendingPathComponent("DSCF0009.JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:00:00")
		try FileManager.default.createSymbolicLink(at: dir.file("link.JPG"), withDestinationURL: dir.file("DSCF0002.JPG"))

		let result = try await FolderScanner.scan(folder: dir.url)

		#expect(result.files.map(\.name) == ["DSCF0002.JPG", "DSCF0003.HIF", "DSCF0010.JPG", "notes.txt"])
		#expect(result.ignoredSubfolders == 1)
		#expect(result.ignoredOther == 1)
		#expect(result.files[0].exifDate?.folderName == "2026-07-19")
		#expect(result.files[1].exifDate?.folderName == "2026-07-20")
		#expect(result.files[1].isImage)
		#expect(result.files[3].exifDate == nil)
		#expect(!result.files[3].isImage)
	}

	@Test func reportsProgressAndFinishesAtTotal() async throws {
		let dir = try TempDir()
		for index in 0..<7 {
			try Fixtures.makeImage(at: dir.file("DSCF000\(index).JPG"), type: .jpeg, dateTimeOriginal: "2026:07:19 12:00:0\(index)")
		}
		let calls = OSAllocatedUnfairLock<[(Int, Int)]>(initialState: [])

		let result = try await FolderScanner.scan(folder: dir.url) { done, total in
			calls.withLock { $0.append((done, total)) }
		}

		#expect(result.files.count == 7)
		let recorded = calls.withLock { $0 }
		#expect(recorded.last?.0 == 7)
		#expect(recorded.last?.1 == 7)
	}

	@Test func emptyFolderScansToNothing() async throws {
		let dir = try TempDir()
		let result = try await FolderScanner.scan(folder: dir.url)
		#expect(result.files.isEmpty)
		#expect(result.ignoredSubfolders == 0)
	}

	@Test func missingFolderThrows() async throws {
		let dir = try TempDir()
		await #expect(throws: (any Error).self) {
			try await FolderScanner.scan(folder: dir.file("does-not-exist"))
		}
	}
}
