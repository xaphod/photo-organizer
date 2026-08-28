//
//  SidebarView.swift
//  PhotoOrganizer
//

import SwiftUI

struct SidebarView: View {
	@Environment(OrganizerModel.self) private var model

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 16) {
				FolderDropZone { model.setFolder($0) }
					.disabled(model.isBusy)

				if let folder = model.folderURL {
					folderInfo(folder)
				}

				operationPicker
				bracketingSection

				if !model.folderSummaries.isEmpty {
					folderList
				}
			}
			.padding(12)
		}
	}

	@ViewBuilder
	private func folderInfo(_ folder: URL) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Label(folder.lastPathComponent, systemImage: "folder")
				.font(.headline)
				.lineLimit(1)
			Text((folder.path as NSString).abbreviatingWithTildeInPath)
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)
				.truncationMode(.middle)
				.help(folder.path)
			if !model.files.isEmpty || model.phase == .ready {
				Text(fileCountText)
					.font(.caption)
			}
			if let warning = model.folderWarning {
				Label(warning, systemImage: "exclamationmark.triangle.fill")
					.font(.caption)
					.foregroundStyle(.orange)
					.padding(.top, 2)
			}
			HStack {
				Button("Rescan") { model.rescan() }
				Button("Clear") { model.clear() }
			}
			.controlSize(.small)
			.disabled(model.isBusy)
			.padding(.top, 4)
		}
	}

	private var fileCountText: String {
		var text = "\(model.files.count) \(model.files.count == 1 ? "file" : "files")"
		if model.ignoredSubfolders > 0 {
			text += " · \(model.ignoredSubfolders) \(model.ignoredSubfolders == 1 ? "subfolder" : "subfolders") ignored"
		}
		return text
	}

	private var operationPicker: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("Operation")
				.font(.headline)
			Picker(
				"Operation",
				selection: Binding(
					get: { model.selectedOperationID },
					set: { model.selectOperation($0) }
				)
			) {
				ForEach(model.operations.indices, id: \.self) { index in
					let operation = model.operations[index]
					Text(operation.name).tag(operation.id)
				}
			}
			.labelsHidden()
			.disabled(model.isBusy)
			if let operation = model.selectedOperation {
				Text(operation.summary)
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}

	private var bracketingSection: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("Film simulation bracketing")
				.font(.headline)
			Toggle(
				"Detect bracketed sets",
				isOn: Binding(
					get: { model.detectBracketSets },
					set: { model.setDetectBracketSets($0) }
				)
			)
			.disabled(model.isBusy)
			Text("Photos with the same capture time form a set; each member is filed under the date folder in a subfolder named for its film simulation (provia, astia, acros…).")
				.font(.caption)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			if model.detectBracketSets, model.phase == .ready {
				if let count = model.detectedCount {
					Text("Detected: \(count) per press, \(model.completeSets) complete \(model.completeSets == 1 ? "set" : "sets")")
						.font(.caption)
				} else {
					Text("No bracketed sets detected")
						.font(.caption)
				}
				if model.unassignedCount > 0 {
					Label("\(model.unassignedCount) \(model.unassignedCount == 1 ? "photo" : "photos") not in a set → filed by date", systemImage: "exclamationmark.triangle.fill")
						.font(.caption)
						.foregroundStyle(.orange)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
	}

	private var folderList: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("Folders")
				.font(.headline)
			ForEach(model.folderSummaries) { item in
				HStack(spacing: 6) {
					Text(item.folder)
						.monospacedDigit()
					if item.isMixed {
						Text("mixed")
							.foregroundStyle(.orange)
							.help("This set folder would receive several film simulations: " + item.filmSimulations.joined(separator: ", "))
					} else if let simulation = item.filmSimulation {
						Text(simulation)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
					Spacer()
					Text("\(item.count)")
						.monospacedDigit()
						.foregroundStyle(.secondary)
				}
				.font(.callout)
			}
		}
	}
}
