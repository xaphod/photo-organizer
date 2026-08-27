//
//  ChangeStatusView.swift
//  PhotoOrganizer
//

import SwiftUI

/// Icon + label for one row's status.
struct ChangeStatusView: View {
	let change: PlannedChange

	var body: some View {
		Label(change.status.label, systemImage: symbolName)
			.foregroundStyle(color)
			.help(change.explanation)
	}

	private var symbolName: String {
		switch change.status {
		case .move: "arrow.right.circle.fill"
		case .alreadyInPlace: "checkmark.circle"
		case .alreadyExists: "exclamationmark.triangle.fill"
		case .noDate: "questionmark.circle.fill"
		case .notAnImage: "minus.circle"
		}
	}

	private var color: Color {
		switch change.status {
		case .move: .green
		case .alreadyInPlace: .secondary
		case .alreadyExists: .orange
		case .noDate: .orange
		case .notAnImage: .secondary
		}
	}
}
