//
//  OrganizedFolderNameTests.swift
//  PhotoOrganizerTests
//

import Foundation
import Testing
@testable import PhotoOrganizer

struct OrganizedFolderNameTests {
	@Test func parsesDateFolders() {
		let plain = OrganizedFolderName.parse("2026-07-19")
		#expect(plain?.date == "2026-07-19")
		#expect(plain?.suffix == nil)
		#expect(plain?.setIndex == nil)
		#expect(plain?.name == "2026-07-19")
	}

	@Test func parsesFilmSimulationFolders() {
		let provia = OrganizedFolderName.parse("2026-07-19-provia")
		#expect(provia?.date == "2026-07-19")
		#expect(provia?.suffix == "provia")
		#expect(provia?.setIndex == nil)
		#expect(provia?.name == "2026-07-19-provia")
		#expect(OrganizedFolderName.parse("2026-07-19-classic-chrome")?.suffix == "classic-chrome")
		#expect(OrganizedFolderName.parse("2026-07-19-switzerland")?.date == "2026-07-19")
	}

	@Test func parsesSetFolders() {
		let set = OrganizedFolderName.parse("2026-07-19-set3")
		#expect(set?.suffix == "set3")
		#expect(set?.setIndex == 3)
		#expect(OrganizedFolderName.parse("2026-07-19-set12")?.setIndex == 12)
		#expect(OrganizedFolderName.parse("2026-07-19-set0")?.setIndex == nil)
		#expect(OrganizedFolderName.parse("2026-07-19-set01")?.setIndex == nil)
		#expect(OrganizedFolderName.parse("2026-07-19-setX")?.setIndex == nil)
		#expect(OrganizedFolderName.parse("2026-07-19-Set1")?.setIndex == nil)
		#expect(OrganizedFolderName.setIndex(of: "set7") == 7)
		#expect(OrganizedFolderName.setIndex(of: "provia") == nil)
		#expect(OrganizedFolderName.setIndex(of: "set") == nil)
	}

	@Test func recognisesWhereADroppedFolderSits() {
		let root = URL(fileURLWithPath: "/Users/tim/Pictures", isDirectory: true)
		#expect(OrganizedFolderName.context(of: root.appendingPathComponent("card")) == nil)
		#expect(OrganizedFolderName.context(of: root.appendingPathComponent("2026-07-19")) == .dateFolder("2026-07-19"))
		#expect(OrganizedFolderName.context(of: root.appendingPathComponent("2026-07-19/acros")) == .insideDateFolder("2026-07-19"))
		#expect(OrganizedFolderName.context(of: root.appendingPathComponent("2026-07-19/set2")) == .insideDateFolder("2026-07-19"))
		#expect(OrganizedFolderName.context(of: root.appendingPathComponent("2026-07-19-acros")) == .insideDateFolder("2026-07-19"))
		#expect(OrganizedFolderName.context(of: root.appendingPathComponent("2026-07-19/acros/extra")) == nil)
		#expect(OrganizedFolderName.context(of: root.appendingPathComponent("2026-07-19-acros/extra")) == nil)
	}

	@Test(arguments: ["2026-07-19-", "2026-07-19x", "2026-07-19 provia", "20260719", "card", "", "2026-7-19-provia"])
	func rejectsOtherNames(_ name: String) {
		#expect(OrganizedFolderName.parse(name) == nil)
	}
}
