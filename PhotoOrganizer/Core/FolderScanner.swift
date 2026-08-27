//
//  FolderScanner.swift
//  PhotoOrganizer
//

import Foundation
import UniformTypeIdentifiers

struct ScanResult: Sendable {
	/// Top-level regular files, sorted by name.
	var files: [PhotoFile]
	/// Subfolders that were skipped (the scan is deliberately non-recursive).
	var ignoredSubfolders: Int
	/// Symlinks, aliases, packages and other non-regular items that were skipped.
	var ignoredOther: Int
}

/// Lists a folder's top-level files and reads each image's EXIF date.
enum FolderScanner {
	private struct Entry: Sendable {
		let url: URL
		let contentType: UTType?
		var isImage: Bool { contentType?.conforms(to: .image) ?? false }
	}

	private struct Listing {
		var files: [Entry] = []
		var ignoredSubfolders = 0
		var ignoredOther = 0
	}

	/// Maximum number of files whose metadata is being read at the same time.
	private static let maxInFlight = 8

	/// Scans `folder` (non-recursively). `progress(done, total)` is called in
	/// batches from a background thread. Throws if the folder can't be listed
	/// or the task is cancelled.
	@concurrent
	static func scan(
		folder: URL,
		progress: @escaping @Sendable (_ done: Int, _ total: Int) -> Void = { _, _ in }
	) async throws -> ScanResult {
		let listing = try listTopLevel(of: folder)
		let entries = listing.files
		let total = entries.count
		var files = [PhotoFile?](repeating: nil, count: total)
		var nextIndex = 0
		var done = 0

		try await withThrowingTaskGroup(of: (Int, ExifDate?).self) { group in
			while nextIndex < min(maxInFlight, total) {
				let index = nextIndex
				let entry = entries[index]
				group.addTask { (index, entry.isImage ? ExifDateReader.read(entry.url) : nil) }
				nextIndex += 1
			}
			while let (index, date) = try await group.next() {
				try Task.checkCancellation()
				let entry = entries[index]
				files[index] = PhotoFile(url: entry.url, contentType: entry.contentType, exifDate: date)
				done += 1
				if done % 50 == 0 || done == total {
					progress(done, total)
				}
				if nextIndex < total {
					let index = nextIndex
					let entry = entries[index]
					group.addTask { (index, entry.isImage ? ExifDateReader.read(entry.url) : nil) }
					nextIndex += 1
				}
			}
		}

		return ScanResult(
			files: files.compactMap { $0 },
			ignoredSubfolders: listing.ignoredSubfolders,
			ignoredOther: listing.ignoredOther
		)
	}

	private static func listTopLevel(of folder: URL) throws -> Listing {
		let keys: Set<URLResourceKey> = [
			.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
			.isAliasFileKey, .isPackageKey, .contentTypeKey,
		]
		let urls = try FileManager.default.contentsOfDirectory(
			at: folder,
			includingPropertiesForKeys: Array(keys),
			options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
		)

		var listing = Listing()
		for url in urls {
			let values = try? url.resourceValues(forKeys: keys)
			if values?.isSymbolicLink == true || values?.isAliasFile == true || values?.isPackage == true {
				listing.ignoredOther += 1
			} else if values?.isDirectory == true {
				listing.ignoredSubfolders += 1
			} else if values?.isRegularFile == true {
				let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
				listing.files.append(Entry(url: url, contentType: type))
			} else {
				listing.ignoredOther += 1
			}
		}
		listing.files.sort {
			$0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
		}
		return listing
	}
}
