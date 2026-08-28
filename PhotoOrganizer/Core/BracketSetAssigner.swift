//
//  BracketSetAssigner.swift
//  PhotoOrganizer
//

import Foundation

/// A photo's place in a bracketing set.
enum SetAssignment: Hashable, Sendable {
	/// Photo `index` (1-based) of a complete set of `count`. `label` is the destination folder
	/// suffix: the film simulation ("provia") when known and unique within the set, else "set<index>".
	case member(index: Int, count: Int, label: String)
	/// Not part of a complete set (a single shot, a run with a deleted frame, an odd-sized run).
	case unassigned(expectedCount: Int?)
}

struct BracketAssignment: Sendable {
	/// Assignment for every image that has a date, keyed by file URL.
	var members: [URL: SetAssignment] = [:]
	/// Detected photos per shutter press (the most common run length), or nil if no run of ≥ 2 exists.
	var detectedCount: Int?
	var completeSets = 0

	var unassignedCount: Int {
		members.values.reduce(0) { count, assignment in
			if case .unassigned = assignment { count + 1 } else { count }
		}
	}
}

/// Detects film-simulation bracketing sets purely from metadata.
///
/// Files of one shutter press share their EXIF date-time *and* sub-second (and, of course,
/// their file type). Walking the files in filename order, maximal runs with the same key are
/// the candidate sets; the most common run length is the camera's photos-per-press, and only
/// runs of exactly that length are treated as sets. Everything else stays unassigned.
enum BracketSetAssigner {
	private struct Key: Hashable {
		let date: ExifDate
		let subsecond: String
		let fileExtension: String
	}

	/// `files` must be in filename order (the scanner's order). Non-images and files without a
	/// date are ignored without breaking the adjacency of the rest.
	static func assign(_ files: [PhotoFile]) -> BracketAssignment {
		var runs: [[PhotoFile]] = []
		var currentKey: Key?
		for file in files {
			guard file.isImage, let date = file.exifDate else { continue }
			let key = Key(date: date, subsecond: file.subsecond ?? "", fileExtension: file.url.pathExtension.uppercased())
			if key == currentKey, !runs.isEmpty {
				runs[runs.count - 1].append(file)
			} else {
				runs.append([file])
				currentKey = key
			}
		}

		var histogram: [Int: Int] = [:]
		for run in runs where run.count >= 2 {
			histogram[run.count, default: 0] += 1
		}
		// Most common run length; ties go to the larger length.
		let detected = histogram.max { a, b in
			a.value < b.value || (a.value == b.value && a.key < b.key)
		}?.key

		var result = BracketAssignment(detectedCount: detected)
		for run in runs {
			if let detected, run.count == detected {
				result.completeSets += 1
				let labels = labels(for: run)
				for (offset, file) in run.enumerated() {
					result.members[file.url] = .member(index: offset + 1, count: detected, label: labels[offset])
				}
			} else {
				for file in run {
					result.members[file.url] = .unassigned(expectedCount: detected)
				}
			}
		}
		return result
	}

	/// Folder suffix for each member of one set: its film simulation's slug when known and not
	/// shared with another member, otherwise "set<position>".
	static func labels(for set: [PhotoFile]) -> [String] {
		let slugs = set.map { $0.filmSimulation?.folderSlug }
		var occurrences: [String: Int] = [:]
		for case let slug? in slugs {
			occurrences[slug, default: 0] += 1
		}
		return slugs.enumerated().map { offset, slug in
			if let slug, occurrences[slug] == 1 { slug } else { "set\(offset + 1)" }
		}
	}
}
