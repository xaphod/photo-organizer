//
//  FolderDropZone.swift
//  PhotoOrganizer
//

import AppKit
import SwiftUI

/// Dashed drop target that accepts exactly one folder, with an open-panel fallback.
struct FolderDropZone: View {
	let onFolder: (URL) -> Void

	@State private var isTargeted = false

	var body: some View {
		VStack(spacing: 8) {
			Image(systemName: "folder.badge.plus")
				.font(.system(size: 34, weight: .light))
				.foregroundStyle(isTargeted ? Color.accentColor : .secondary)
			Text("Drop a folder here")
				.font(.headline)
			Text("or")
				.font(.caption)
				.foregroundStyle(.secondary)
			Button("Choose Folder…", action: chooseFolder)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 22)
		.background(
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
		)
		.overlay(
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.strokeBorder(style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4]))
				.foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.6))
		)
		.dropDestination(for: URL.self) { urls, _ in
			guard urls.count == 1, let url = urls.first, Self.isDirectory(url) else { return false }
			onFolder(url)
			return true
		} isTargeted: { targeted in
			isTargeted = targeted
		}
		.animation(.easeInOut(duration: 0.15), value: isTargeted)
	}

	private func chooseFolder() {
		let panel = NSOpenPanel()
		panel.canChooseDirectories = true
		panel.canChooseFiles = false
		panel.allowsMultipleSelection = false
		panel.prompt = "Choose"
		panel.message = "Choose the folder containing the photos to organize."
		if panel.runModal() == .OK, let url = panel.url {
			onFolder(url)
		}
	}

	static func isDirectory(_ url: URL) -> Bool {
		var isDirectory: ObjCBool = false
		return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
	}
}
