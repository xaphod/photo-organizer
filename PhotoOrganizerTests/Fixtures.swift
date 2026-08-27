//
//  Fixtures.swift
//  PhotoOrganizerTests
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import PhotoOrganizer

/// A unique scratch directory, deleted when the instance goes away.
final class TempDir {
	let url: URL

	init() throws {
		url = FileManager.default.temporaryDirectory
			.appendingPathComponent("PhotoOrganizerTests-\(UUID().uuidString)", isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
	}

	deinit {
		try? FileManager.default.removeItem(at: url)
	}

	func file(_ relativePath: String) -> URL {
		url.appendingPathComponent(relativePath)
	}

	func makeSubfolder(_ name: String) throws -> URL {
		let folder = url.appendingPathComponent(name, isDirectory: true)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		return folder
	}

	/// Every path under the directory, relative and sorted (hidden files included).
	func listing() throws -> [String] {
		try FileManager.default.subpathsOfDirectory(atPath: url.path).sorted()
	}
}

enum Fixtures {
	enum FixtureError: Error {
		case context, destination, finalize
	}

	/// Writes a tiny 4×4 image of `type` (JPEG or HEIC) with the given EXIF DateTimeOriginal.
	static func makeImage(at url: URL, type: UTType, dateTimeOriginal: String?) throws {
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
			space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
		) else { throw FixtureError.context }
		context.setFillColor(CGColor(red: 1, green: 0.5, blue: 0, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))

		guard let image = context.makeImage(),
			  let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
		else { throw FixtureError.destination }

		var properties: [CFString: Any] = [:]
		if let dateTimeOriginal {
			properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: dateTimeOriginal]
		}
		CGImageDestinationAddImage(destination, image, properties as CFDictionary)
		guard CGImageDestinationFinalize(destination) else { throw FixtureError.finalize }
	}

	static func writeText(_ text: String, at url: URL) throws {
		try Data(text.utf8).write(to: url)
	}
}
