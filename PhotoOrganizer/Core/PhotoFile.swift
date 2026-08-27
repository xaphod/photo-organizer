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
	/// Camera-local date taken, or nil if the file has no EXIF date.
	let exifDate: ExifDate?

	var id: URL { url }
	var name: String { url.lastPathComponent }

	/// True for anything ImageIO can read (JPEG, HEIF/HIF, RAW, PNG, TIFF…).
	var isImage: Bool { contentType?.conforms(to: .image) ?? false }
}
