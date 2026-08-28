//
//  ThumbnailCache.swift
//  PhotoOrganizer
//

import CoreGraphics
import Foundation

/// Bounded in-memory caches of row thumbnails and enlarged previews. Deliberately not
/// `@Observable`: images arriving must never re-render the whole table.
@MainActor
final class ThumbnailCache {
	static let shared = ThumbnailCache()

	private let small = NSCache<NSURL, CGImage>()
	private let large = NSCache<NSURL, CGImage>()

	init(smallLimit: Int = 500, largeLimit: Int = 24) {
		small.countLimit = smallLimit
		large.countLimit = largeLimit
	}

	func image(for url: URL) -> CGImage? {
		small.object(forKey: url as NSURL)
	}

	func store(_ image: CGImage, for url: URL) {
		small.setObject(image, forKey: url as NSURL)
	}

	func largeImage(for url: URL) -> CGImage? {
		large.object(forKey: url as NSURL)
	}

	func storeLarge(_ image: CGImage, for url: URL) {
		large.setObject(image, forKey: url as NSURL)
	}

	func removeAll() {
		small.removeAllObjects()
		large.removeAllObjects()
	}
}
