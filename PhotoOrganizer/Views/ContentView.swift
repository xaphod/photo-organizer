//
//  ContentView.swift
//  PhotoOrganizer
//

import SwiftUI

struct ContentView: View {
	@Environment(OrganizerModel.self) private var model

	var body: some View {
		NavigationSplitView {
			SidebarView()
				.navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 380)
		} detail: {
			PreviewPane()
		}
		.frame(minWidth: 760, minHeight: 440)
	}
}

#Preview {
	ContentView()
		.environment(OrganizerModel())
}
