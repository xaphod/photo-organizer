//
//  PlannedChange.swift
//  PhotoOrganizer
//

import Foundation

/// What one operation would do to one file.
///
/// Produced by `OrganizeOperation.plan`, shown in the preview table, and — for
/// `.move` rows only — carried out by `ChangeExecutor`.
struct PlannedChange: Identifiable, Hashable, Sendable {
	enum Status: Hashable, Sendable, CaseIterable {
		/// Will be moved to `destination`.
		case move
		/// The folder it is in is already named for its date; nothing to do.
		case alreadyInPlace
		/// A file with the same name already exists at the destination. Never overwritten.
		case alreadyExists
		/// No EXIF date taken could be read. Left where it is.
		case noDate
		/// Not an image file (video, sidecar, text…). Left where it is.
		case notAnImage

		var label: String {
			switch self {
			case .move: "Move"
			case .alreadyInPlace: "Already in place"
			case .alreadyExists: "Already exists"
			case .noDate: "No EXIF date"
			case .notAnImage: "Not an image"
			}
		}

		/// Sort key for the Status column: actionable rows first.
		var rank: Int {
			switch self {
			case .move: 0
			case .alreadyInPlace: 1
			case .alreadyExists: 2
			case .noDate: 3
			case .notAnImage: 4
			}
		}
	}

	let file: PhotoFile
	/// Where the file would end up. Set for `.move` and `.alreadyExists` (to show where it *would* have gone).
	let destination: URL?
	let status: Status
	/// Bracket-set position, when set detection was on and the file is a dated image.
	let set: SetAssignment?
	/// Destination folder relative to the chosen folder, e.g. "2026-07-19" or "2026-07-19/acros"; nil when there is none.
	let relativeFolder: String?
	/// Destination relative to the chosen folder, e.g. "2026-07-19/acros/DSCF0373.HIF"; "" when there is none.
	let relativeDestination: String
	/// "YYYY-MM-DD HH:mm:ss" or "" when the file has no date. Precomputed so table rows do no formatting.
	let dateDisplay: String

	init(file: PhotoFile, destination: URL? = nil, status: Status, set: SetAssignment? = nil, relativeFolder: String? = nil) {
		self.file = file
		self.destination = destination
		self.status = status
		self.set = set
		self.relativeFolder = relativeFolder
		relativeDestination = relativeFolder.map { $0 + "/" + file.name } ?? ""
		dateDisplay = file.exifDate?.displayString ?? ""
	}

	var id: URL { file.url }
	var name: String { file.name }
	var statusRank: Int { status.rank }

	/// 1-based position in its set, or 0 (sort key for the Set column).
	var setIndex: Int {
		if case .member(let index, _, _) = set { index } else { 0 }
	}

	/// "1 of 3", "none" (not in a complete set), or "".
	var setDisplay: String {
		switch set {
		case .member(let index, let count, _): "\(index) of \(count)"
		case .unassigned: "none"
		case nil: ""
		}
	}

	/// Folder suffix chosen for this set member ("provia", "set2"), if any.
	var setLabel: String? {
		if case .member(_, _, let label) = set { label } else { nil }
	}

	/// Friendly film-simulation name, when known.
	var filmSimulation: String? { file.filmSimulation?.displayName }

	/// Full explanation for a tooltip.
	var explanation: String {
		switch status {
		case .move:
			switch set {
			case .member(let index, let count, _):
				"Will move to \(relativeDestination) — photo \(index) of \(count) in its set\(filmSimulation.map { " (\($0))" } ?? "")"
			case .unassigned(let expected):
				"Not part of a complete set\(expected.map { " of \($0) photos" } ?? "") sharing one capture time — will be filed by date only, into \(relativeDestination)"
			case nil:
				"Will move to \(relativeDestination)"
			}
		case .alreadyInPlace:
			"Already inside a folder named for its date — nothing to do"
		case .alreadyExists:
			"Skipped: a file named \(name) already exists in \(relativeFolder ?? "the destination folder")"
		case .noDate:
			"Skipped: no EXIF date taken could be read from this file"
		case .notAnImage:
			"Skipped: not an image file"
		}
	}
}
