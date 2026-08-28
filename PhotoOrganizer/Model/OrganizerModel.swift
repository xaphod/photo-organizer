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

	/// One destination folder in the sidebar list.
	struct FolderSummary: Identifiable {
		let folder: String
		let count: Int
		/// Dominant film simulation — only reported for "setN" fallback folders, where it should be uniform.
		let filmSimulation: String?
		/// True if a set folder would receive more than one film simulation (a sign the sets are misaligned).
		let isMixed: Bool
		let filmSimulations: [String]
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
	/// Bracket-set detection from the last plan (nil when detection is off).
	private(set) var bracketing: BracketAssignment?
	/// Whether "Move into date folders" files bracketed sets into "-setN" folders.
	private(set) var detectBracketSets: Bool

	private static let detectBracketSetsKey = "bracketing.enabled"

	private static let logger = Logger(subsystem: "com.solodigitalis.PhotoOrganizer", category: "organizer")

	@ObservationIgnored private var scanTask: Task<Void, Never>?
	/// Incremented whenever the folder changes or a rescan starts, so results
	/// from a superseded scan or execution are ignored.
	@ObservationIgnored private var generation = 0

	init() {
		selectedOperationID = OrganizeOperations.all.first?.id ?? ""
		detectBracketSets = UserDefaults.standard.bool(forKey: Self.detectBracketSetsKey)
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

	var options: OrganizeOptions { OrganizeOptions(detectBracketSets: detectBracketSets) }

	/// Detected photos per shutter press (nil if detection is off or nothing was detected).
	var detectedCount: Int? { bracketing?.detectedCount }
	var completeSets: Int { bracketing?.completeSets ?? 0 }
	/// Dated images that are not part of a complete set (filed by date only).
	var unassignedCount: Int { bracketing?.unassignedCount ?? 0 }

	/// Files that will move, per destination folder, sorted by folder name.
	var folderSummaries: [FolderSummary] {
		var counts: [String: Int] = [:]
		var simulations: [String: [String: Int]] = [:]
		for change in changes where change.status == .move {
			guard let folder = change.relativeFolder else { continue }
			counts[folder, default: 0] += 1
			if let simulation = change.filmSimulation {
				simulations[folder, default: [:]][simulation, default: 0] += 1
			}
		}
		return counts.keys.sorted().map { folder in
			let isSetFolder = OrganizedFolderName.setIndex(of: (folder as NSString).lastPathComponent) != nil
			let histogram = simulations[folder] ?? [:]
			let dominant = histogram.max { $0.value < $1.value }?.key
			return FolderSummary(
				folder: folder,
				count: counts[folder]!,
				filmSimulation: isSetFolder ? dominant : nil,
				isMixed: isSetFolder && histogram.count > 1,
				filmSimulations: histogram.keys.sorted()
			)
		}
	}

	var destinationFolderCount: Int {
		Set(changes.lazy.filter { $0.status == .move }.compactMap(\.relativeFolder)).count
	}

	/// "312 files · 300 will move into 2 folders · 12 skipped · 4 not in a set"
	var summaryText: String {
		let folders = destinationFolderCount
		var parts = [
			"\(changes.count) \(changes.count == 1 ? "file" : "files")",
			"\(moveCount) will move into \(folders) \(folders == 1 ? "folder" : "folders")",
			"\(skippedCount) skipped",
		]
		if detectBracketSets, unassignedCount > 0 {
			parts.append("\(unassignedCount) not in a set")
		}
		return parts.joined(separator: " · ")
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
		ThumbnailCache.shared.removeAll()
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
		bracketing = nil

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
				Self.logger.notice("Scan complete: \(result.files.count) files, \(result.ignoredSubfolders) subfolders ignored; \(self.summaryText, privacy: .public); bracket detection \(self.detectBracketSets ? "on, detected \(self.detectedCount.map(String.init) ?? "none"), \(self.completeSets) complete sets" : "off", privacy: .public)")
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

	/// Turns bracket-set detection on or off; re-plans from the metadata already in memory.
	func setDetectBracketSets(_ enabled: Bool) {
		guard enabled != detectBracketSets, !isBusy else { return }
		detectBracketSets = enabled
		UserDefaults.standard.set(enabled, forKey: Self.detectBracketSetsKey)
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
		bracketing = nil
		ignoredSubfolders = 0
		lastReport = nil
		phase = .empty
		ThumbnailCache.shared.removeAll()
	}

	// MARK: Helpers

	private func replan() {
		guard let folder = folderURL, let operation = selectedOperation else {
			changes = []
			bracketing = nil
			return
		}
		let result = operation.plan(files: files, in: folder, options: options)
		changes = result.changes
		bracketing = result.bracketing
	}

	private static func warning(for folder: URL) -> String? {
		let values = try? folder.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])
		let onRemovableVolume = values?.volumeIsRemovable == true || values?.volumeIsEjectable == true
		let looksLikeCard = folder.pathComponents.contains("DCIM")
		guard onRemovableVolume || looksLikeCard else { return nil }
		return "This looks like a camera card. Organizing files on the card itself can confuse the camera — consider organizing a copy on your Mac instead."
	}
}
