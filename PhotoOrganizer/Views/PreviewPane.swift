//
//  PreviewPane.swift
//  PhotoOrganizer
//

import SwiftUI

/// Right-hand pane: shows what the selected operation will do, and the Go button.
struct PreviewPane: View {
	@Environment(OrganizerModel.self) private var model
	@State private var sortOrder = [KeyPathComparator(\PlannedChange.name)]

	var body: some View {
		VStack(spacing: 0) {
			if let report = model.lastReport {
				ReportBanner(report: report) { model.dismissReport() }
				Divider()
			}
			content
		}
	}

	@ViewBuilder
	private var content: some View {
		switch model.phase {
		case .empty:
			ContentUnavailableView(
				"No Folder",
				systemImage: "photo.on.rectangle.angled",
				description: Text("Drop a folder in the sidebar to preview what will change.")
			)
		case .scanning(let done, let total):
			VStack(spacing: 12) {
				ProgressView(value: total > 0 ? Double(done) / Double(total) : nil)
					.frame(maxWidth: 320)
				Text(total > 0 ? "Reading photo dates… \(done) of \(total)" : "Reading folder…")
					.font(.callout)
					.foregroundStyle(.secondary)
					.monospacedDigit()
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		case .failed(let message):
			ContentUnavailableView(
				"Couldn't Read Folder",
				systemImage: "exclamationmark.triangle",
				description: Text(message)
			)
		case .ready, .executing:
			table
			Divider()
			bottomBar
		}
	}

	private var table: some View {
		Table(model.changes.sorted(using: sortOrder), sortOrder: $sortOrder) {
			TableColumn("File", value: \.name) { change in
				Text(change.name)
					.help(change.file.url.path)
			}
			TableColumn("Date taken", value: \.dateDisplay) { change in
				Text(change.dateDisplay.isEmpty ? "—" : change.dateDisplay)
					.monospacedDigit()
					.foregroundStyle(change.dateDisplay.isEmpty ? .secondary : .primary)
					.help("Date and time from the photo's EXIF data, in the camera's local time")
			}
			.width(min: 150, ideal: 160)
			TableColumn("Destination", value: \.relativeDestination) { change in
				Text(change.relativeDestination.isEmpty ? "—" : change.relativeDestination)
					.foregroundStyle(change.status == .move ? .primary : .secondary)
			}
			TableColumn("Status", value: \.statusRank) { change in
				ChangeStatusView(change: change)
			}
			.width(min: 130, ideal: 150)
		}
	}

	private var bottomBar: some View {
		HStack(spacing: 12) {
			Text(model.summaryText)
				.font(.callout)
				.foregroundStyle(.secondary)
				.monospacedDigit()
			Spacer()
			if case .executing(let done, let total) = model.phase {
				ProgressView(value: Double(done), total: Double(max(total, 1)))
					.frame(width: 160)
				Text("Moving \(done) of \(total)…")
					.font(.callout)
					.monospacedDigit()
			} else {
				Button("Go") { model.go() }
					.keyboardShortcut(.defaultAction)
					.buttonStyle(.borderedProminent)
					.controlSize(.large)
					.disabled(model.moveCount == 0)
					.help(model.moveCount == 0 ? "Nothing to move" : "Move \(model.moveCount) files now")
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
}

/// Summary of the last Go, shown above the refreshed table.
struct ReportBanner: View {
	let report: ExecutionReport
	let dismiss: () -> Void

	@State private var showFailures = false

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack {
				Label(headline, systemImage: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
					.foregroundStyle(report.failures.isEmpty ? Color.green : Color.orange)
					.font(.callout.weight(.medium))
				Spacer()
				Button("Dismiss", action: dismiss)
					.controlSize(.small)
			}
			if !report.failures.isEmpty {
				DisclosureGroup("Failures (\(report.failures.count))", isExpanded: $showFailures) {
					VStack(alignment: .leading, spacing: 2) {
						ForEach(report.failures) { failure in
							Text("\(failure.change.name) — \(failure.message)")
								.font(.caption)
								.textSelection(.enabled)
						}
					}
					.padding(.top, 2)
				}
				.font(.caption)
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.background(Color.primary.opacity(0.04))
	}

	private var headline: String {
		let files = report.movedCount == 1 ? "file" : "files"
		let folders = report.folderCount == 1 ? "folder" : "folders"
		var text = "Moved \(report.movedCount) \(files) into \(report.folderCount) \(folders)"
		if !report.failures.isEmpty {
			text += " · \(report.failures.count) failed"
		}
		return text
	}
}
