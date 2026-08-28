//
//  ThumbnailView.swift
//  PhotoOrganizer
//

import CoreGraphics
import SwiftUI

/// A row's small preview image, loaded lazily and cached. Always occupies the same 60×40 pt
/// frame so table rows never change height as images arrive. Click to enlarge.
struct ThumbnailView: View {
	let change: PlannedChange

	@State private var image: CGImage?
	@State private var showPreview = false

	private var url: URL { change.file.url }
	private var isImage: Bool { change.file.isImage }

	var body: some View {
		Button {
			showPreview = true
		} label: {
			ZStack {
				RoundedRectangle(cornerRadius: 3, style: .continuous)
					.fill(Color.primary.opacity(0.06))
				if let image {
					Image(decorative: image, scale: 2)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
				} else if !isImage {
					Image(systemName: "doc")
						.foregroundStyle(.tertiary)
				}
			}
			.frame(width: 60, height: 40)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.disabled(!isImage)
		.help(isImage ? "Click to enlarge" : "Not an image")
		.popover(isPresented: $showPreview, arrowEdge: .trailing) {
			LargePreviewView(change: change)
		}
		.onAppear {
			if image == nil {
				image = ThumbnailCache.shared.image(for: url)
			}
		}
		.task(id: url) {
			guard isImage else { return }
			if let cached = ThumbnailCache.shared.image(for: url) {
				image = cached
				return
			}
			guard let loaded = await ThumbnailLoader.thumbnail(for: url) else { return }
			ThumbnailCache.shared.store(loaded, for: url)
			if !Task.isCancelled {
				image = loaded
			}
		}
	}
}

/// Popover content: a sharp ~512 px rendering of the photo plus its key facts.
struct LargePreviewView: View {
	static let maxPixelSize = 512

	let change: PlannedChange

	@State private var image: CGImage?
	@State private var failed = false

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ZStack {
				if let image {
					Image(decorative: image, scale: 1)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
				} else if failed {
					Label("Couldn't load a preview", systemImage: "photo")
						.foregroundStyle(.secondary)
				} else {
					ProgressView()
				}
			}
			.frame(width: CGFloat(Self.maxPixelSize), height: CGFloat(Self.maxPixelSize))
			Text(change.name)
				.font(.headline)
				.textSelection(.enabled)
			Text(details)
				.font(.caption)
				.foregroundStyle(.secondary)
				.textSelection(.enabled)
		}
		.padding(12)
		.task(id: change.file.url) {
			let url = change.file.url
			if let cached = ThumbnailCache.shared.largeImage(for: url) {
				image = cached
				return
			}
			guard let loaded = await ThumbnailLoader.thumbnail(for: url, maxPixelSize: Self.maxPixelSize, fromFullImage: true) else {
				failed = true
				return
			}
			ThumbnailCache.shared.storeLarge(loaded, for: url)
			image = loaded
		}
	}

	private var details: String {
		var parts: [String] = []
		if !change.dateDisplay.isEmpty { parts.append(change.dateDisplay) }
		if let simulation = change.filmSimulation { parts.append(simulation) }
		if !change.setDisplay.isEmpty { parts.append("set: \(change.setDisplay)") }
		if !change.relativeDestination.isEmpty { parts.append("→ \(change.relativeDestination)") }
		return parts.isEmpty ? change.status.label : parts.joined(separator: " · ")
	}
}
