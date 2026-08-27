//
//  OrganizerModel.swift
//  PhotoOrganizer
//

import Foundation
import Observation
import os

/// UI state for the main window: the chosen folder, the selected operation,
/// the scan/plan/execute lifecycle, and the resulting preview rows.
@MainActor
@Observable
final class OrganizerModel {
	enum Phase: Equatable {
		case empty
		case scanning(done: Int, total: Int)
		case ready
		case executing(done: Int, total: Int)
		case failed(String)
	}

	struct FolderCount: Identifiable {
		let folder: String
		let count: Int
		var id: String { folder }
	}

	private(set) var folderURL: URL?
	private(set) var folderWarning: String?
	let operations: [any OrganizeOperation] = OrganizeOperations.all
	private(set) var selectedOperationID: String
	private(set) var phase: Phase = .empty
	private(set) var files: [PhotoFile] = []
	private(set) var ignoredSubfolders = 0
	private(set) var changes: [PlannedChange] = []
	private(set) var lastReport: ExecutionReport?

	private static let logger = Logger(subsystem: "com.solodigitalis.PhotoOrganizer", category: "organizer")

	@ObservationIgnored private var scanTask: Task<Void, Never>?
	/// Incremented whenever the folder changes or a rescan starts, so results
	/// from a superseded scan or execution are ignored.
	@ObservationIgnored private var generation = 0

	init() {
		selectedOperationID = OrganizeOperations.all.first?.id ?? ""
	}

	// MARK: Derived state

	var selectedOperation: (any OrganizeOperation)? {
		OrganizeOperations.operation(withID: selectedOperationID)
	}

	var isBusy: Bool {
		switch phase {
		case .scanning, .executing: true
		default: false
		}
	}

	var moveCount: Int {
		changes.reduce(0) { $0 + ($1.status == .move ? 1 : 0) }
	}

	var skippedCount: Int { changes.count - moveCount }

	/// Number of files that will move, per destination folder, sorted by folder name.
	var perFolderCounts: [FolderCount] {
		var counts: [String: Int] = [:]
		for change in changes where change.status == .move {
			if let folder = change.destinationFolderName {
				counts[folder, default: 0] += 1
			}
		}
		return counts.keys.sorted().map { FolderCount(folder: $0, count: counts[$0]!) }
	}

	var destinationFolderCount: Int { perFolderCounts.count }

	/// "312 files · 300 will move into 2 folders · 12 skipped"
	var summaryText: String {
		let folders = destinationFolderCount
		return [
			"\(changes.count) \(changes.count == 1 ? "file" : "files")",
			"\(moveCount) will move into \(folders) \(folders == 1 ? "folder" : "folders")",
			"\(skippedCount) skipped",
		].joined(separator: " · ")
	}

	// MARK: Actions

	/// Chooses a folder (from a drop, the open panel, or a launch argument) and scans it.
	func setFolder(_ url: URL) {
		if case .executing = phase { return }
		var isDirectory: ObjCBool = false
		guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
			phase = .failed("\(url.lastPathComponent) is not a folder.")
			return
		}
		let folder = url.standardizedFileURL
		folderURL = folder
		folderWarning = Self.warning(for: folder)
		lastReport = nil
		Self.logger.notice("Folder set: \(folder.path, privacy: .public)")
		rescan()
	}

	/// Re-reads the folder and re-plans. Cancels any scan already running.
	func rescan() {
		guard let folder = folderURL else { return }
		scanTask?.cancel()
		generation += 1
		let generation = generation
		phase = .scanning(done: 0, total: 0)
		files = []
		changes = []

		scanTask = Task {
			do {
				let result = try await FolderScanner.scan(folder: folder) { done, total in
					Task { @MainActor [weak self] in
						guard let self, self.generation == generation else { return }
						self.phase = .scanning(done: done, total: total)
					}
				}
				guard self.generation == generation else { return }
				self.files = result.files
				self.ignoredSubfolders = result.ignoredSubfolders
				self.replan()
				self.phase = .ready
				Self.logger.notice("Scan complete: \(result.files.count) files, \(result.ignoredSubfolders) subfolders ignored; \(self.summaryText, privacy: .public)")
			} catch is CancellationError {
				// Superseded by a newer scan; its results will land instead.
			} catch {
				guard self.generation == generation else { return }
				Self.logger.error("Scan failed: \(error.localizedDescription, privacy: .public)")
				self.phase = .failed(error.localizedDescription)
			}
		}
	}

	func selectOperation(_ id: String) {
		guard id != selectedOperationID, OrganizeOperations.operation(withID: id) != nil else { return }
		selectedOperationID = id
		if phase == .ready { replan() }
	}

	/// Carries out the current plan, then rescans so the table shows the new state on disk.
	func go() {
		guard phase == .ready, moveCount > 0 else { return }
		let plan = changes
		let generation = generation
		phase = .executing(done: 0, total: moveCount)

		Task {
			let report = await ChangeExecutor.execute(plan) { done, total in
				Task { @MainActor [weak self] in
					guard let self, self.generation == generation else { return }
					self.phase = .executing(done: done, total: total)
				}
			}
			guard self.generation == generation else { return }
			Self.logger.notice("Go complete: moved \(report.movedCount) files into \(report.folderCount) folders, \(report.failures.count) failed")
			self.lastReport = report
			self.rescan()
		}
	}

	func dismissReport() {
		lastReport = nil
	}

	func clear() {
		if case .executing = phase { return }
		scanTask?.cancel()
		generation += 1
		folderURL = nil
		folderWarning = nil
		files = []
		changes = []
		ignoredSubfolders = 0
		lastReport = nil
		phase = .empty
	}

	// MARK: Helpers

	private func replan() {
		guard let folder = folderURL, let operation = selectedOperation else {
			changes = []
			return
		}
		changes = operation.plan(files: files, in: folder)
	}

	private static func warning(for folder: URL) -> String? {
		let values = try? folder.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])
		let onRemovableVolume = values?.volumeIsRemovable == true || values?.volumeIsEjectable == true
		let looksLikeCard = folder.pathComponents.contains("DCIM")
		guard onRemovableVolume || looksLikeCard else { return nil }
		return "This looks like a camera card. Organizing files on the card itself can confuse the camera — consider organizing a copy on your Mac instead."
	}
}
