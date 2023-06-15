//
//  SoundingLocationListTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 6/11/23.
//

import XCTest
@testable import Skewt

final class SoundingLocationListTests: XCTestCase {
    var locationListString: String!
    var expectedStationCount: Int!

    var soundingsListString: String!
    var expectedSoundingsCount: Int!
    
    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        let locationsFile = bundle.url(forResource: "raob", withExtension: "short")!
        let locationsData = try Data(contentsOf: locationsFile)
        locationListString = String(data: locationsData, encoding: .utf8)!
        expectedStationCount = 1157
        
        let soundingsFile = bundle.url(forResource: "latest_pbraob", withExtension: "txt")!
        let soundingsData = try Data(contentsOf: soundingsFile)
        soundingsListString = String(data: soundingsData, encoding: .utf8)!
        expectedSoundingsCount = 804
    }
    
    func testLoadsWithVaryingHeaders() throws {
        for headerCullCount in 0...2 {
            let allLines = locationListString.components(separatedBy: .newlines)
            let lines = allLines[headerCullCount...].map { String($0) }
            let locationInfo = try LocationList(String(lines.joined(separator: "\n")))
            
            XCTAssertEqual(locationInfo.locations.count, expectedStationCount)
        }
    }
    
    func testMissingHeader() {
        let allLines = locationListString.components(separatedBy: .newlines)
        let headerIndex = allLines.firstIndex(where: { $0.hasPrefix("Name") })!
        let linesMinusHeader = allLines[(headerIndex + 1)...]
        
        do {
            let _ = try LocationList(String(linesMinusHeader.joined(separator: "\n")))
            XCTFail("Loading a location list without a header should throw an error")
        } catch LocationListParsingError.missingHeader {
            return
        } catch {
            XCTFail("Loading a location list without a header should throw a .missingHeader error")
        }
    }
    
    func testUnparseableLines() {
        let allLines = locationListString.components(separatedBy: .newlines)
        let insertionIndex = 420
        
        let stupidLines = [
            "This 12345 is a 12345.63 -5555.5 22 broken line with no station info",
            "NJK  7228.1   32.82 -115.68  -13 El Centro Naf, CA/US",  // . in station ID
            "NJK  72281   32.82 --115.68  -13 El Centro Naf, CA/US",  // double negative in longitude
            "NJK  72281   32.82 -115.6.8  -13 El Centro Naf, CA/US",  // double . in longitude
            "NJK  72281   32.82 -115.68  -13.2 El Centro Naf, CA/US",  // decimal in elevation
            "I put an onion on my belt, which was the fashion at the time."
        ]
        
        for stupidLine in stupidLines {
            let lines = allLines[..<insertionIndex] + [stupidLine] + allLines[insertionIndex...]

            do {
                let _ = try LocationList(String(lines.joined(separator: "\n")))
                XCTFail("Loading a location list with an unparseable line should throw an error")
            } catch LocationListParsingError.unparseableLine(let failedLine) {
                XCTAssertEqual(failedLine, stupidLine)
            } catch {
                XCTFail("Loading a location list with an unparseable line should throw an .unparseableLine error")
            }
        }
    }
    
    func testLocationParsing() throws {
        let elCentro = try LocationList.Location("NJK  72281   32.82 -115.68  -13 El Centro Naf, CA/US")
        XCTAssertEqual(elCentro.name, "NJK")
        XCTAssertEqual(elCentro.id, 72281)
        XCTAssertEqual(elCentro.latitude, 32.82)
        XCTAssertEqual(elCentro.longitude, -115.68)
        XCTAssertEqual(elCentro.elevation, -13)
        XCTAssertEqual(elCentro.description, "El Centro Naf, CA/US")
        
        let yining = try LocationList.Location("ZWYN -51431   43.95   81.33  663 Yining, CI")
        XCTAssertEqual(yining.name, "ZWYN")
        XCTAssertEqual(yining.id, -51431)
        XCTAssertEqual(yining.latitude, 43.95)
        XCTAssertEqual(yining.longitude, 81.33)
        XCTAssertEqual(yining.elevation, 663)
        XCTAssertEqual(yining.description, "Yining, CI")
    }
    
    func testStationId() {
        let wmo = LatestSoundingList.Entry("-51431, 2022-10-27 12:00:00")!
        XCTAssertEqual(wmo.stationId, .wmoId(-51431))
        
        let slashes = LatestSoundingList.Entry("///, 2023-01-24 12:00:00")!
        XCTAssertEqual(slashes.stationId, .bufr("///"))
        
        let longBufrName = LatestSoundingList.Entry("XKQLWQB, 2023-06-11 12:00:00")!
        XCTAssertEqual(longBufrName.stationId, .bufr("XKQLWQB"))
    }
    
    func testSoundingsListParsing() throws {
        let soundings = try LatestSoundingList(soundingsListString)
        XCTAssertEqual(soundings.soundings.count, expectedSoundingsCount)
    }
    
    func testIgnoreUnparseableStationInfoLines() {
        XCTAssertNil(LatestSoundingList.Entry("WMOID Name ---------latest date-------------"))
        XCTAssertNil(LatestSoundingList.Entry(""))
        XCTAssertNil(LatestSoundingList.Entry("NKX, Time is a flat circle"))
    }
    
    func testSoundingTimestampParsing() {
        let midnight = LatestSoundingList.Entry("03918, 2023-06-11 00:00:00")!
        let noon = LatestSoundingList.Entry("03953, 2023-06-11 12:00:00")!
        let calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(secondsFromGMT: 0)!

        let midnightComponents = calendar.dateComponents(in: utc, from: midnight.timestamp)
        let noonComponents = calendar.dateComponents(in: utc, from: noon.timestamp)
        
        [midnightComponents, noonComponents].forEach {
            XCTAssertEqual($0.year, 2023)
            XCTAssertEqual($0.month, 6)
            XCTAssertEqual($0.day, 11)
        }
        
        XCTAssertEqual(midnightComponents.hour, 0)
        XCTAssertEqual(noonComponents.hour, 12)
    }
}