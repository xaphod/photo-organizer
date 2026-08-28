//
//  MoveIntoDateFoldersOperation.swift
//  PhotoOrganizer
//

import Foundation

/// Moves each photo into a `YYYY-MM-DD/` subfolder named from its EXIF date taken — and, with
/// bracket-set detection on, set members one level deeper into `YYYY-MM-DD/<film simulation>/`
/// (e.g. `2026-07-19/acros`; `setN` when the simulation is unknown). Filenames are never changed
/// and existing files are never overwritten.
struct MoveIntoDateFoldersOperation: OrganizeOperation {
	let id = "move-into-date-folders"
	let name = "Move into date folders"
	let summary = "Moves each photo into a YYYY-MM-DD subfolder based on its EXIF date taken. Filenames are not changed."

	func plan(files: [PhotoFile], in folder: URL, options: OrganizeOptions) -> PlanResult {
		let fileManager = FileManager.default
		let context = OrganizedFolderName.context(of: folder)
		let bracketing = options.detectBracketSets ? BracketSetAssigner.assign(files) : nil
		// Destinations already claimed by an earlier file in this plan (lower-cased so
		// DSCF0001.JPG and dscf0001.jpg collide the way they would on APFS/exFAT).
		var claimed = Set<String>()

		let changes = files.map { file -> PlannedChange in
			guard file.isImage else {
				return PlannedChange(file: file, status: .notAnImage)
			}
			guard let date = file.exifDate else {
				return PlannedChange(file: file, status: .noDate)
			}

			let set = bracketing?.members[file.url]
			var label: String?
			if case .member(_, _, let memberLabel) = set {
				label = memberLabel
			}

			// Path components below the dropped folder. Never nest a date folder inside one
			// already named for that date.
			var components: [String]
			switch context {
			case .insideDateFolder(let contextDate) where contextDate == date.folderName:
				return PlannedChange(file: file, status: .alreadyInPlace, set: set)
			case .dateFolder(let contextDate) where contextDate == date.folderName:
				guard let label else {
					return PlannedChange(file: file, status: .alreadyInPlace, set: set)
				}
				components = [label]
			default:
				components = [date.folderName]
				if let label { components.append(label) }
			}

			let relativeFolder = components.joined(separator: "/")
			var destination = folder
			for component in components {
				destination.appendPathComponent(component, isDirectory: true)
			}
			destination.appendPathComponent(file.name, isDirectory: false)
			let key = destination.path.lowercased()

			if fileManager.fileExists(atPath: destination.path) || claimed.contains(key) {
				return PlannedChange(file: file, destination: destination, status: .alreadyExists, set: set, relativeFolder: relativeFolder)
			}
			claimed.insert(key)
			return PlannedChange(file: file, destination: destination, status: .move, set: set, relativeFolder: relativeFolder)
		}
		return PlanResult(changes: changes, bracketing: bracketing)
	}
}
