import XCTest
@testable import EpicWorld

/// Guards the Dart-compatibility layer every ported parser and date
/// calculation relies on.
final class DateTimeTests: XCTestCase {
    func testParseWithoutZoneIsLocal() throws {
        let value = try DateTime.parse("2026-09-02 08:15:30.250")
        XCTAssertFalse(value.isUtc)
        XCTAssertEqual([value.year, value.month, value.day, value.hour, value.minute, value.second, value.millisecond],
                       [2026, 9, 2, 8, 15, 30, 250])
    }

    func testParseWithZoneIsUtcAndAppliesOffset() throws {
        let zulu = try DateTime.parse("2026-09-02T08:00:00Z")
        XCTAssertTrue(zulu.isUtc)
        XCTAssertEqual(zulu.hour, 8)

        let offset = try DateTime.parse("2026-09-02T08:00:00+06:30")
        XCTAssertTrue(offset.isUtc)
        XCTAssertEqual(offset.hour, 1)
        XCTAssertEqual(offset.minute, 30)
    }

    func testDateOnlyAndCompactForms() {
        XCTAssertEqual(DateTime.tryParse("2026-09-02"), DateTime(2026, 9, 2))
        XCTAssertEqual(DateTime.tryParse("20260902"), DateTime(2026, 9, 2))
        XCTAssertNil(DateTime.tryParse("02/09/2026"))
        XCTAssertNil(DateTime.tryParse(""))
    }

    func testFieldsRollOverLikeDart() {
        XCTAssertEqual(DateTime(2026, 9, 0), DateTime(2026, 8, 31))
        XCTAssertEqual(DateTime(2026, 13, 1), DateTime(2027, 1, 1))
        XCTAssertEqual(DateTime(2026, 1, 31, 24), DateTime(2026, 2, 1))
    }

    func testWeekdayIsMondayOne() {
        XCTAssertEqual(DateTime(2026, 9, 7).weekday, 1) // Monday
        XCTAssertEqual(DateTime(2026, 9, 13).weekday, 7) // Sunday
    }

    func testEqualityIncludesUtcFlagButComparisonIsByInstant() {
        let utc = DateTime.utc(2026, 9, 1, 12)
        let local = utc.toLocal()
        XCTAssertNotEqual(utc, local)
        XCTAssertTrue(utc.isAtSameMomentAs(local))
        XCTAssertEqual(utc.compareTo(local), 0)
    }

    func testIsoStringsMatchDart() {
        XCTAssertEqual(DateTime.utc(2026, 9, 2, 8).toIso8601String(), "2026-09-02T08:00:00.000Z")
        XCTAssertEqual(DateTime(2026, 9, 2, 8, 5, 3, 7).toIso8601String(), "2026-09-02T08:05:03.007")
        XCTAssertEqual(DateTime(2026, 9, 2).description, "2026-09-02 00:00:00.000")
    }

    func testDifferenceAndDurations() {
        let a = DateTime(2026, 9, 2, 10, 30)
        let b = DateTime(2026, 9, 2, 8)
        XCTAssertEqual(a.difference(b).inMinutes, 150)
        XCTAssertEqual(b.difference(a).inMinutes, -150)
        XCTAssertEqual(Duration(minutes: -90).inHours, -1) // truncates toward zero
        XCTAssertTrue(Duration(seconds: -1).isNegative)
    }
}

final class DartValueTests: XCTestCase {
    private func decoded(_ json: String) -> JSON {
        try! JSONSerialization.jsonObject(with: Data(json.utf8)) as! JSON
    }

    func testNumbersBoolsAndNullsAreToldApart() {
        let json = decoded(#"{"i": 3, "d": 3.5, "w": 3.0, "t": true, "n": null, "s": "3"}"#)
        XCTAssertTrue(Dart.isInt(json["i"]))
        XCTAssertTrue(Dart.isDouble(json["d"]))
        XCTAssertTrue(Dart.isBool(json["t"]))
        XCTAssertFalse(Dart.isNum(json["t"]))
        XCTAssertFalse(Dart.isBool(json["i"]))
        XCTAssertTrue(Dart.isNull(json["n"]))
        XCTAssertNil(Dart.double(json["s"]))
        XCTAssertEqual(Dart.int(json["d"]), 3)
        XCTAssertEqual(Dart.double(json["i"]), 3)
    }

    func testToStringMatchesDart() {
        let json = decoded(#"{"i": 3, "w": 3.0, "t": false, "n": null}"#)
        XCTAssertEqual(Dart.str(json["i"]), "3")
        XCTAssertEqual(Dart.str(json["w"]), "3.0")
        XCTAssertEqual(Dart.str(json["t"]), "false")
        XCTAssertNil(Dart.str(json["n"]))
        XCTAssertEqual(Dart.interpolate(json["n"]), "null")
    }

    func testParsers() {
        XCTAssertEqual(Dart.parseDouble(" 12.5 "), 12.5)
        XCTAssertEqual(Dart.parseDouble("1e3"), 1000)
        XCTAssertNil(Dart.parseDouble("12abc"))
        XCTAssertEqual(Dart.parseInt("-42"), -42)
        XCTAssertEqual(Dart.parseInt("0x1F"), 31)
        XCTAssertNil(Dart.parseInt("4.2"))
    }

    func testMapsAndLists() {
        let json = decoded(#"{"m": {"a": 1}, "l": [{"b": 2}, 3, null]}"#)
        XCTAssertEqual(Dart.int(Dart.map(json["m"])?["a"]), 1)
        XCTAssertEqual(Dart.maps(json["l"]).count, 1)
        XCTAssertNil(Dart.map(json["l"]))
    }
}

final class L10nTests: XCTestCase {
    func testMissingKeyReturnsTheKey() {
        XCTAssertEqual("no.such.key".tr(), "no.such.key")
    }

    func testPositionalArgsReplaceBracesInOrder() {
        // Exercised through a key that does not exist, so the key text itself
        // is the template.
        XCTAssertEqual("{} of {}".tr(args: ["1", "3"]), "1 of 3")
    }
}
