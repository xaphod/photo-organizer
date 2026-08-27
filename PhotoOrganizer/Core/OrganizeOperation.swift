//
//  OrganizeOperation.swift
//  PhotoOrganizer
//

import Foundation

/// Something the app can do to the files in a folder.
///
/// Planning is pure: it inspects the file system but never modifies it. Only
/// `ChangeExecutor` writes, and only when the user presses Go.
protocol OrganizeOperation: Sendable {
	/// Stable identifier (used for the picker selection).
	var id: String { get }
	/// Short name shown in the picker.
	var name: String { get }
	/// One or two sentences describing what the operation does.
	var summary: String { get }

	func plan(files: [PhotoFile], in folder: URL) -> [PlannedChange]
}

/// Registry of the operations offered in the sidebar picker.
/// To add an operation: write a new `OrganizeOperation` type and list it here.
enum OrganizeOperations {
	static let all: [any OrganizeOperation] = [
		MoveIntoDateFoldersOperation(),
	]

	static func operation(withID id: String) -> (any OrganizeOperation)? {
		all.first { $0.id == id }
	}
}
