//
//  ChangeExecutor.swift
//  PhotoOrganizer
//

import Foundation

/// Outcome of one Go.
struct ExecutionReport: Sendable {
	struct Failure: Identifiable, Sendable {
		let id = UUID()
		let change: PlannedChange
		let message: String
	}

	/// Every change that was carried out, in order (source → destination). Kept
	/// in memory so a future "Undo" can reverse the moves.
	var moved: [PlannedChange] = []
	/// Names of the date folders this run created.
	var foldersCreated: Set<String> = []
	var failures: [Failure] = []

	var movedCount: Int { moved.count }
	/// Number of distinct folders that received files.
	var folderCount: Int {
		Set(moved.compactMap(\.destinationFolderName)).count
	}
}

/// Carries out the `.move` rows of a plan. The only code in the app that writes to disk.
enum ChangeExecutor {
	enum ExecutorError: LocalizedError {
		case sourceMissing
		case destinationExists

		var errorDescription: String? {
			switch self {
			case .sourceMissing: "The file is no longer in the folder."
			case .destinationExists: "A file with the same name already exists at the destination."
			}
		}
	}

	/// Moves the files of every `.move` change. Files are never overwritten: the
	/// destination is re-checked immediately before each move, and a failure on
	/// one file never stops the others. `progress(done, total)` is called in
	/// batches from a background thread.
	@concurrent
	static func execute(
		_ changes: [PlannedChange],
		progress: @escaping @Sendable (_ done: Int, _ total: Int) -> Void = { _, _ in }
	) async -> ExecutionReport {
		let fileManager = FileManager.default
		let moves = changes.filter { $0.status == .move }
		let total = moves.count
		var report = ExecutionReport()

		// Create each destination folder once, up front. If one can't be created,
		// the moves into it fail individually below with a clear message.
		let folders = Set(moves.compactMap { $0.destination?.deletingLastPathComponent() })
		for folder in folders.sorted(by: { $0.path < $1.path }) {
			if fileManager.fileExists(atPath: folder.path) { continue }
			do {
				try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
				report.foldersCreated.insert(folder.lastPathComponent)
			} catch {
				continue
			}
		}

		for (index, change) in moves.enumerated() {
			defer {
				if (index + 1) % 25 == 0 || index + 1 == total {
					progress(index + 1, total)
				}
			}
			guard let destination = change.destination else { continue }
			do {
				guard fileManager.fileExists(atPath: change.file.url.path) else {
					throw ExecutorError.sourceMissing
				}
				guard !fileManager.fileExists(atPath: destination.path) else {
					throw ExecutorError.destinationExists
				}
				try fileManager.moveItem(at: change.file.url, to: destination)
				report.moved.append(change)
			} catch {
				report.failures.append(.init(change: change, message: error.localizedDescription))
			}
		}
		return report
	}
}
