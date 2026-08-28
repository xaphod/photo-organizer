//
//  BracketSetAssignerTests.swift
//  PhotoOrganizerTests
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import PhotoOrganizer

struct BracketSetAssignerTests {
	private let base = URL(fileURLWithPath: "/card", isDirectory: true)

	private func hif(_ number: Int, _ time: String, sub: String? = "17", type: UTType = .heif) -> PhotoFile {
		Fixtures.photo(base.appendingPathComponent(String(format: "DSCF%04d.%@", number, type == .heif ? "HIF" : type == .jpeg ? "JPG" : "RAF")),
					   type: type, date: "2026:07:19 \(time)", subsecond: sub)
	}

	/// A set member whose film simulation is unknown → folder suffix "set<index>".
	private func member(_ index: Int, of count: Int) -> SetAssignment {
		.member(index: index, count: count, label: "set\(index)")
	}

	private func assignment(of file: PhotoFile, in result: BracketAssignment) -> SetAssignment? {
		result.members[file.url]
	}

	@Test func assignsIndicesToCompletePresses() {
		let files = [
			hif(1, "12:21:42"), hif(2, "12:21:42"), hif(3, "12:21:42"),
			hif(4, "12:21:53", sub: "32"), hif(5, "12:21:53", sub: "32"), hif(6, "12:21:53", sub: "32"),
		]
		let result = BracketSetAssigner.assign(files)
		#expect(result.detectedCount == 3)
		#expect(result.completeSets == 2)
		#expect(result.unassignedCount == 0)
		#expect(files.map { assignment(of: $0, in: result) } == [
			member(1, of: 3), member(2, of: 3), member(3, of: 3),
			member(1, of: 3), member(2, of: 3), member(3, of: 3),
		])
	}

	@Test func singleShotBetweenSetsStaysUnassigned() {
		let files = [
			hif(1, "12:21:42"), hif(2, "12:21:42"), hif(3, "12:21:42"),
			hif(4, "12:21:50", sub: "05"),
			hif(5, "12:21:53", sub: "32"), hif(6, "12:21:53", sub: "32"), hif(7, "12:21:53", sub: "32"),
		]
		let result = BracketSetAssigner.assign(files)
		#expect(result.detectedCount == 3)
		#expect(result.completeSets == 2)
		#expect(assignment(of: files[3], in: result) == .unassigned(expectedCount: 3))
		#expect(assignment(of: files[4], in: result) == member(1, of: 3))
		#expect(assignment(of: files[6], in: result) == member(3, of: 3))
	}

	@Test func deletedFrameLeavesItsPressUnassignedAndRealigns() {
		let files = [
			hif(1, "12:21:42"), hif(2, "12:21:42"), hif(3, "12:21:42"),
			hif(4, "12:21:53", sub: "32"), hif(6, "12:21:53", sub: "32"),   // frame 5 deleted in camera
			hif(7, "12:22:00", sub: "40"), hif(8, "12:22:00", sub: "40"), hif(9, "12:22:00", sub: "40"),
		]
		let result = BracketSetAssigner.assign(files)
		#expect(result.detectedCount == 3)
		#expect(result.completeSets == 2)
		#expect(result.unassignedCount == 2)
		#expect(assignment(of: files[3], in: result) == .unassigned(expectedCount: 3))
		#expect(assignment(of: files[4], in: result) == .unassigned(expectedCount: 3))
		#expect(assignment(of: files[5], in: result) == member(1, of: 3))
	}

	@Test func differentSubsecondsInTheSameSecondAreDifferentPresses() {
		let files = [
			hif(1, "12:21:42", sub: "10"), hif(2, "12:21:42", sub: "10"), hif(3, "12:21:42", sub: "10"),
			hif(4, "12:21:42", sub: "90"), hif(5, "12:21:42", sub: "90"), hif(6, "12:21:42", sub: "90"),
		]
		let result = BracketSetAssigner.assign(files)
		#expect(result.completeSets == 2)
		#expect(assignment(of: files[3], in: result) == member(1, of: 3))
	}

	@Test func detectsOtherSetSizes() {
		let pairs = [hif(1, "12:21:42"), hif(2, "12:21:42"), hif(3, "12:21:50", sub: "20"), hif(4, "12:21:50", sub: "20")]
		let pairResult = BracketSetAssigner.assign(pairs)
		#expect(pairResult.detectedCount == 2)
		#expect(pairResult.completeSets == 2)

		let six = (1...6).map { hif($0, "12:21:42") } + (7...12).map { hif($0, "12:22:42", sub: "50") }
		let sixResult = BracketSetAssigner.assign(six)
		#expect(sixResult.detectedCount == 6)
		#expect(sixResult.completeSets == 2)
		#expect(assignment(of: six[11], in: sixResult) == member(6, of: 6))
	}

	@Test func mostCommonRunLengthWins() {
		// Two presses of 3 and one damaged press of 2 → 3 wins; the pair stays unassigned.
		let files = [
			hif(1, "12:21:42"), hif(2, "12:21:42"), hif(3, "12:21:42"),
			hif(4, "12:21:50", sub: "20"), hif(5, "12:21:50", sub: "20"),
			hif(6, "12:21:55", sub: "30"), hif(7, "12:21:55", sub: "30"), hif(8, "12:21:55", sub: "30"),
		]
		let result = BracketSetAssigner.assign(files)
		#expect(result.detectedCount == 3)
		#expect(result.unassignedCount == 2)
	}

	@Test func noRunsMeansNothingDetected() {
		let files = [hif(1, "12:21:42", sub: "10"), hif(2, "12:21:43", sub: "20"), hif(3, "12:21:44", sub: "30")]
		let result = BracketSetAssigner.assign(files)
		#expect(result.detectedCount == nil)
		#expect(result.completeSets == 0)
		#expect(result.unassignedCount == 3)
		#expect(assignment(of: files[0], in: result) == .unassigned(expectedCount: nil))
	}

	@Test func differentFileTypesNeverShareASet() {
		// RAW+HEIF pairs written together: same timestamp, different extension.
		let files = [
			hif(1, "12:21:42"), hif(1, "12:21:42", type: .rawImage), hif(2, "12:21:42"), hif(2, "12:21:42", type: .rawImage), hif(3, "12:21:42"), hif(3, "12:21:42", type: .rawImage),
		]
		// Files arrive in filename order: DSCF0001.HIF, DSCF0001.RAF, DSCF0002.HIF, …
		let ordered = files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
		let result = BracketSetAssigner.assign(ordered)
		// Alternating extensions break every run into singles → nothing detected, nothing mis-assigned.
		#expect(result.detectedCount == nil)
		#expect(result.completeSets == 0)
	}

	@Test func ignoresNonImagesAndUndatedFilesWithoutBreakingAdjacency() {
		let files = [
			hif(1, "12:21:42"),
			Fixtures.photo(base.appendingPathComponent("notes.txt"), type: .plainText, date: nil),
			hif(2, "12:21:42"),
			Fixtures.photo(base.appendingPathComponent("DSCF0099.JPG"), type: .jpeg, date: nil),
			hif(3, "12:21:42"),
		]
		let result = BracketSetAssigner.assign(files)
		#expect(result.detectedCount == 3)
		#expect(result.completeSets == 1)
		#expect(result.members.count == 3)
		#expect(assignment(of: files[4], in: result) == member(3, of: 3))
	}

	@Test func labelsMembersByFilmSimulation() {
		let provia = FilmSimulation(rawName: "F0/Standard", filmModeCode: 0x000)
		let astia = FilmSimulation(rawName: "F1b/Studio Portrait Smooth Skin Tone", filmModeCode: 0x120)
		let acros = FilmSimulation(monochromeCode: 0x500)
		let files = [
			Fixtures.photo(base.appendingPathComponent("DSCF0001.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", filmSimulation: provia),
			Fixtures.photo(base.appendingPathComponent("DSCF0002.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", filmSimulation: astia),
			Fixtures.photo(base.appendingPathComponent("DSCF0003.HIF"), type: .heif, date: "2026:07:19 12:21:42", subsecond: "17", filmSimulation: acros),
		]
		let result = BracketSetAssigner.assign(files)
		#expect(files.map { assignment(of: $0, in: result) } == [
			.member(index: 1, count: 3, label: "provia"),
			.member(index: 2, count: 3, label: "astia"),
			.member(index: 3, count: 3, label: "acros"),
		])
	}

	@Test func fallsBackToSetPositionForUnknownOrDuplicateSimulations() {
		let velvia = FilmSimulation(rawName: "F2/Fujichrome (Velvia)", filmModeCode: 0x200)
		let classicChrome = FilmSimulation(rawName: "Classic Chrome", filmModeCode: 0x600)
		#expect(BracketSetAssigner.labels(for: [
			Fixtures.photo(base.appendingPathComponent("a.HIF"), date: "2026:07:19 12:21:42", filmSimulation: velvia),
			Fixtures.photo(base.appendingPathComponent("b.HIF"), date: "2026:07:19 12:21:42", filmSimulation: nil),
			Fixtures.photo(base.appendingPathComponent("c.HIF"), date: "2026:07:19 12:21:42", filmSimulation: classicChrome),
		]) == ["velvia", "set2", "classic-chrome"])
		// Two members with the same simulation would collide → both fall back to their position.
		#expect(BracketSetAssigner.labels(for: [
			Fixtures.photo(base.appendingPathComponent("a.HIF"), date: "2026:07:19 12:21:42", filmSimulation: velvia),
			Fixtures.photo(base.appendingPathComponent("b.HIF"), date: "2026:07:19 12:21:42", filmSimulation: velvia),
			Fixtures.photo(base.appendingPathComponent("c.HIF"), date: "2026:07:19 12:21:42", filmSimulation: classicChrome),
		]) == ["set1", "set2", "classic-chrome"])
	}

	@Test func subsecondIsOptional() {
		let files = [hif(1, "12:21:42", sub: nil), hif(2, "12:21:42", sub: nil), hif(3, "12:21:42", sub: nil)]
		let result = BracketSetAssigner.assign(files)
		#expect(result.detectedCount == 3)
		#expect(result.completeSets == 1)
	}
}
