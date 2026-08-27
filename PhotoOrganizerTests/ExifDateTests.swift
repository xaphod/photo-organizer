//
//  ExifDateTests.swift
//  PhotoOrganizerTests
//

import Testing
@testable import PhotoOrganizer

struct ExifDateTests {
	@Test func parsesStandardString() throws {
		let date = try #require(ExifDate(exifString: "2026:07:19 12:22:21"))
		#expect(date.folderName == "2026-07-19")
		#expect(date.displayString == "2026-07-19 12:22:21")
		#expect(date.year == 2026 && date.month == 7 && date.day == 19)
		#expect(date.hour == 12 && date.minute == 22 && date.second == 21)
	}

	@Test func toleratesMissingTime() {
		#expect(ExifDate(exifString: "2026:07:19")?.folderName == "2026-07-19")
		#expect(ExifDate(exifString: "  2026:07:19 12:22:21  ")?.displayString == "2026-07-19 12:22:21")
	}

	@Test(arguments: [
		"",
		"    :  :     :  :  ",
		"0000:00:00 00:00:00",
		"garbage",
		"2026:13:01 00:00:00",
		"2026:07:32 00:00:00",
		"2026:07:19 25:00:00",
		"2026:07",
		"2026-07-19 12:22:21",
		"2026:07:19 12:22",
	])
	func rejectsInvalidStrings(_ string: String) {
		#expect(ExifDate(exifString: string) == nil)
	}

	@Test func recognisesDateFolderNames() {
		#expect(ExifDate.isDateFolderName("2026-07-19"))
		#expect(!ExifDate.isDateFolderName("20260719"))
		#expect(!ExifDate.isDateFolderName("2026-7-19"))
		#expect(!ExifDate.isDateFolderName("2026-07-19x"))
		#expect(!ExifDate.isDateFolderName("card"))
		#expect(!ExifDate.isDateFolderName(""))
	}
}
