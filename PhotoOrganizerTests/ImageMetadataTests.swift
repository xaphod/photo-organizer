//
//  ImageMetadataTests.swift
//  PhotoOrganizerTests
//

import Testing
@testable import PhotoOrganizer

struct ImageMetadataTests {
	@Test func parsesDateAndSubsecond() {
		let metadata = ImageMetadata(properties: [
			"{Exif}": ["DateTimeOriginal": "2026:07:19 12:21:42", "SubsecTimeOriginal": "17"],
		])
		#expect(metadata.dateTaken?.displayString == "2026-07-19 12:21:42")
		#expect(metadata.subsecond == "17")
		#expect(metadata.filmSimulation == nil)
	}

	@Test func fallsBackThroughDateAndSubsecondFields() {
		let metadata = ImageMetadata(properties: [
			"{Exif}": ["DateTimeDigitized": "2026:07:19 12:21:42", "SubsecTime": " 5 "],
			"{TIFF}": ["DateTime": "2000:01:01 00:00:00"],
		])
		#expect(metadata.dateTaken?.folderName == "2026-07-19")
		#expect(metadata.subsecond == "5")
		#expect(ImageMetadata(properties: ["{TIFF}": ["DateTime": "2000:01:01 00:00:00"]]).dateTaken?.folderName == "2000-01-01")
		#expect(ImageMetadata(properties: ["{Exif}": ["SubsecTimeOriginal": "   "]]).subsecond == nil)
		#expect(ImageMetadata(properties: [:]).dateTaken == nil)
	}

	@Test func parsesColourFilmSimulation() {
		let metadata = ImageMetadata(properties: [
			"{PictureStyle}": ["FilmSimulation": ["F1b/Studio Portrait Smooth Skin Tone", 288, 288]],
		])
		#expect(metadata.filmSimulation?.rawName == "F1b/Studio Portrait Smooth Skin Tone")
		#expect(metadata.filmSimulation?.filmModeCode == 0x120)
		#expect(metadata.filmSimulation?.displayName == "Astia")
	}

	@Test func parsesMonochromeFromSaturationCode() {
		let acros = ImageMetadata(properties: ["{PictureStyle}": ["Saturation": [1280, 1280, 0]]])
		#expect(acros.filmSimulation?.monochromeCode == 0x500)
		#expect(acros.filmSimulation?.displayName == "Acros")

		let colour = ImageMetadata(properties: ["{PictureStyle}": ["Saturation": ["Normal", 0, 0]]])
		#expect(colour.filmSimulation == nil)

		let unknownMono = ImageMetadata(properties: ["{PictureStyle}": ["Saturation": [0x3F0, 0x3F0, 0]]])
		#expect(unknownMono.filmSimulation?.displayName == "Monochrome 0x3F0")
	}

	@Test(arguments: [
		(0x000, "Provia"), (0x120, "Astia"), (0x200, "Velvia"), (0x400, "Velvia"),
		(0x600, "Classic Chrome"), (0x700, "Eterna"), (0x800, "Classic Neg."), (0xB00, "Reala ACE"),
	])
	func namesKnownFilmModes(code: Int, name: String) {
		#expect(FilmSimulation(rawName: "Fx/whatever", filmModeCode: code).displayName == name)
	}

	@Test(arguments: [
		(0x000, "provia"), (0x120, "astia"), (0x600, "classic-chrome"), (0x500, "pro-neg-std"),
		(0x501, "pro-neg-hi"), (0x800, "classic-neg"), (0xA00, "nostalgic-neg"), (0x110, "studio-portrait-enh-sat"),
	])
	func makesFolderSlugs(code: Int, slug: String) {
		#expect(FilmSimulation(filmModeCode: code).folderSlug == slug)
	}

	@Test func makesMonochromeAndFallbackSlugs() {
		#expect(FilmSimulation(monochromeCode: 0x501).folderSlug == "acros-r")
		#expect(FilmSimulation(monochromeCode: 0x3F0).folderSlug == "monochrome-0x3f0")
		#expect(FilmSimulation(rawName: "F9/Future Look", filmModeCode: 0xF00).folderSlug == "future-look")
		#expect(FilmSimulation().folderSlug == nil)
	}

	@Test func unknownCodeFallsBackToStrippedRawName() {
		#expect(FilmSimulation(rawName: "F9/Future Look", filmModeCode: 0xF00).displayName == "Future Look")
		#expect(FilmSimulation(rawName: "NoSlash", filmModeCode: 0xF00).displayName == "NoSlash")
		#expect(FilmSimulation(pictureStyle: nil) == nil)
		#expect(FilmSimulation(pictureStyle: [:]) == nil)
		#expect(FilmSimulation(pictureStyle: ["FilmSimulation": []]) == nil)
	}
}
