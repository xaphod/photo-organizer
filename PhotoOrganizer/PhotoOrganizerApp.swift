//
//  PhotoOrganizerApp.swift
//  PhotoOrganizer
//

import SwiftUI

@main
struct PhotoOrganizerApp: App {
	@State private var model: OrganizerModel

	init() {
		let model = OrganizerModel()
		// Developer convenience: `open PhotoOrganizer.app --args -folder ~/Pictures/card`
		if let path = UserDefaults.standard.string(forKey: "folder"), !path.isEmpty {
			model.setFolder(URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
		}
		_model = State(initialValue: model)
	}

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environment(model)
		}
		.defaultSize(width: 1000, height: 640)
	}
}
