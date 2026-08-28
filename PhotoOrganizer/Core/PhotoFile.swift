//
//  PhotoFile.swift
//  PhotoOrganizer
//

import Foundation
import UniformTypeIdentifiers

/// One top-level file in the chosen folder, plus what the scanner learned about it.
struct PhotoFile: Identifiable, Hashable, Sendable {
	let url: URL
	let contentType: UTType?
	let metadata: ImageMetadata

	init(url: URL, contentType: UTType?, metadata: ImageMetadata) {
		self.url = url
		self.contentType = contentType
		self.metadata = metadata
	}

	/// Convenience for callers that only know the date.
	init(url: URL, contentType: UTType?, exifDate: ExifDate?) {
		self.init(url: url, contentType: contentType, metadata: ImageMetadata(dateTaken: exifDate))
	}

	var id: URL { url }
	var name: String { url.lastPathComponent }

	/// Camera-local date taken, or nil if the file has no EXIF date.
	var exifDate: ExifDate? { metadata.dateTaken }
	var subsecond: String? { metadata.subsecond }
	var filmSimulation: FilmSimulation? { metadata.filmSimulation }

	/// True for anything ImageIO can read (JPEG, HEIF/HIF, RAW, PNG, TIFF…).
	var isImage: Bool { contentType?.conforms(to: .image) ?? false }
}
