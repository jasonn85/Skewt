//
//  SoundingLocationListTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 6/11/23.
//

import XCTest
@testable import Skewt
import CoreLocation

final class SoundingLocationListTests: XCTestCase {
    var soundingLocationListString: String!
    var expectedStationCount: Int!
    
    var metarLocationListString: String!
    var expectedMetarLocationCount: Int!

    var soundingsListString: String!
    var expectedSoundingsCount: Int!
    
    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        
        let soundingLocationsFile = bundle.url(forResource: "raob", withExtension: "short")!
        let soundingLocationsData = try Data(contentsOf: soundingLocationsFile)
        soundingLocationListString = String(data: soundingLocationsData, encoding: .utf8)!
        expectedStationCount = 1158
        
        let metarLocationsFile = bundle.url(forResource: "metar", withExtension: "short")!
        let metarLocationsData = try Data(contentsOf: metarLocationsFile)
        metarLocationListString = String(data: metarLocationsData, encoding: .utf8)!
        expectedMetarLocationCount = 7414
        
        let soundingsFile = bundle.url(forResource: "latest_pbraob", withExtension: "txt")!
        let soundingsData = try Data(contentsOf: soundingsFile)
        soundingsListString = String(data: soundingsData, encoding: .utf8)!
        expectedSoundingsCount = 804
    }
    
    func testLoadsWithVaryingHeaders() throws {
        for headerCullCount in 0...2 {
            let allLines = soundingLocationListString.components(separatedBy: .newlines)
            let lines = allLines[headerCullCount...].map { String($0) }
            let locationInfo = try LocationList(String(lines.joined(separator: "\n")))
            
            XCTAssertEqual(locationInfo.locations.count, expectedStationCount)
        }
    }
    
    /// Test that unparseable lines are silently discarded
    func testUnparseableLines() throws {
        let allLines = soundingLocationListString.components(separatedBy: .newlines)
        let insertionIndex = 420
        
        let stupidLines = [
            "(Ordered by state or province, or country name, then south to north)",
            "This 12345 is a 12345.63 -5555.5 22 broken line with no station info",
            "NJK  7228.1   32.82 -115.68  -13 El Centro Naf, CA/US",  // . in station ID
            "NJK  72281   32.82 --115.68  -13 El Centro Naf, CA/US",  // double negative in longitude
            "NJK  72281   32.82 -115.6.8  -13 El Centro Naf, CA/US",  // double . in longitude
            "NJK  72281   32.82 -115.68  -13.2 El Centro Naf, CA/US",  // decimal in elevation
            "I put an onion on my belt, which was the fashion at the time."
        ]
        
        for stupidLine in stupidLines {
            let lines = allLines[..<insertionIndex] + [stupidLine] + allLines[insertionIndex...]
            let locationList = try LocationList(String(lines.joined(separator: "\n")))
            XCTAssertEqual(locationList.locations.count, expectedStationCount)
        }
    }
    
    func testLocationParsing() throws {
        let elCentro = try LocationList.Location("NJK  72281   32.82 -115.68  -13 El Centro Naf, CA/US")
        XCTAssertEqual(elCentro.name, "NJK")
        XCTAssertEqual(elCentro.wmoId, 72281)
        XCTAssertEqual(elCentro.latitude, 32.82)
        XCTAssertEqual(elCentro.longitude, -115.68)
        XCTAssertEqual(elCentro.elevation, -13)
        XCTAssertEqual(elCentro.description, "El Centro Naf, CA/US")
        
        let yining = try LocationList.Location("ZWYN -51431   43.95   81.33  663 Yining, CI")
        XCTAssertEqual(yining.name, "ZWYN")
        XCTAssertEqual(yining.wmoId, -51431)
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
    
    func testMetarListParsing() throws {
        let metarList = try LocationList(metarLocationListString)
        XCTAssertEqual(metarList.locations.count, expectedMetarLocationCount)
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
    
    func testRecentSoundingFilter() {
        let yearOldSounding = LatestSoundingList.Entry(
            stationId: .wmoId(1),
            timestamp: Date(timeIntervalSinceNow: -365.0 * 24.0 * 60.0 * 60.0)
        )
        
        let weekOldSounding = LatestSoundingList.Entry(
            stationId: .wmoId(2),
            timestamp: Date(timeIntervalSinceNow: -7.0 * 24.0 * 60.0 * 60.0)
        )
        
        let twentyHourOldSounding = LatestSoundingList.Entry(
            stationId: .wmoId(3),
            timestamp: Date(timeIntervalSinceNow: -20.0 * 60.0 * 60.0)
        )
        
        let twelveHourOldSounding = LatestSoundingList.Entry(
            stationId: .wmoId(4),
            timestamp: Date(timeIntervalSinceNow: -12.0 * 60.0 * 60.0)
        )
        
        let hourOldSounding = LatestSoundingList.Entry(
            stationId: .wmoId(5),
            timestamp: Date(timeIntervalSinceNow: -60.0 * 60.0)
        )
        
        let hourInFutureSounding = LatestSoundingList.Entry(
            stationId: .wmoId(6),
            timestamp: Date(timeIntervalSinceNow: 60.0 * 60.0)
        )
        
        let oneSounding = LatestSoundingList(soundings: [hourOldSounding])
        XCTAssertEqual(oneSounding.recentSoundings(), oneSounding.soundings)
        
        let allRecentSoundings = LatestSoundingList(soundings: [twentyHourOldSounding, twelveHourOldSounding, hourOldSounding])
        XCTAssertEqual(allRecentSoundings.recentSoundings(), allRecentSoundings.soundings)
        
        let ancientSoundings = LatestSoundingList(soundings: [yearOldSounding, weekOldSounding])
        XCTAssertEqual(ancientSoundings.recentSoundings(), [])
        
        let oneOldOneCurrentSounding = LatestSoundingList(soundings: [yearOldSounding, hourOldSounding])
        XCTAssertEqual(oneOldOneCurrentSounding.recentSoundings(), [hourOldSounding])
        
        let futureSounding = LatestSoundingList(soundings: [hourInFutureSounding])
        XCTAssertEqual(futureSounding.recentSoundings(), [])
    }
    
    func testProximitySorting() throws {
        let metarList = try LocationList(metarLocationListString)
        let nearSanLocation = CLLocation(latitude: 32.74, longitude: -117.22)
        
        let sorted = metarList.locationsSortedByProximity(to: nearSanLocation)
        XCTAssertEqual(sorted.count, metarList.locations.count)
        XCTAssertEqual(sorted.first?.name, "SAN")
        XCTAssertEqual(sorted[1].name, "NZY")
    }
    
    func testInitialDataInAssets() throws {
        let metarData = try LocationList.forType(.op40)
        let soundingData = try LocationList.forType(.raob)
        
        XCTAssertTrue(metarData.locations.contains { $0.name == "MYF" })
        XCTAssertTrue(soundingData.locations.contains { $0.name == "NKX" })
    }
}
