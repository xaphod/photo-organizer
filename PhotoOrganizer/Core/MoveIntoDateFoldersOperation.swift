//
//  MoveIntoDateFoldersOperation.swift
//  PhotoOrganizer
//

import Foundation

/// Moves each photo into a `YYYY-MM-DD` subfolder named from its EXIF date
/// taken. Filenames are never changed and existing files are never overwritten.
struct MoveIntoDateFoldersOperation: OrganizeOperation {
	let id = "move-into-date-folders"
	let name = "Move into date folders"
	let summary = "Moves each photo into a YYYY-MM-DD subfolder based on its EXIF date taken. Filenames are not changed."

	func plan(files: [PhotoFile], in folder: URL) -> [PlannedChange] {
		let fileManager = FileManager.default
		let folderName = folder.lastPathComponent
		let folderIsDateFolder = ExifDate.isDateFolderName(folderName)
		// Destinations already claimed by an earlier file in this plan (lower-cased so
		// DSCF0001.JPG and dscf0001.jpg collide the way they would on APFS/exFAT).
		var claimed = Set<String>()

		return files.map { file in
			guard file.isImage else {
				return PlannedChange(file: file, status: .notAnImage)
			}
			guard let date = file.exifDate else {
				return PlannedChange(file: file, status: .noDate)
			}
			if folderIsDateFolder && folderName == date.folderName {
				return PlannedChange(file: file, status: .alreadyInPlace)
			}

			let destination = folder
				.appendingPathComponent(date.folderName, isDirectory: true)
				.appendingPathComponent(file.name, isDirectory: false)
			let key = destination.path.lowercased()

			if fileManager.fileExists(atPath: destination.path) || claimed.contains(key) {
				return PlannedChange(file: file, destination: destination, status: .alreadyExists)
			}
			claimed.insert(key)
			return PlannedChange(file: file, destination: destination, status: .move)
		}
	}
}
