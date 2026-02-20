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
            XCTAssertEqual(locationList.locations.count, expectedStationCount,
                           "\"\(stupidLine)\" should not be parsed as a valid location entry")
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
    
    func testMetarListParsing() throws {
        let metarList = try LocationList(metarLocationListString)
        XCTAssertEqual(metarList.locations.count, expectedMetarLocationCount)
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
        let metarData = try LocationList.forType(.forecast(.automatic))
        let soundingData = try LocationList.forType(.sounding)
        
        XCTAssertTrue(metarData.locations.contains { $0.name == "MYF" })
        XCTAssertTrue(soundingData.locations.contains { $0.name == "NKX" })
    }
    
    func testAllTypes() throws {
        let master = LocationList.allLocations
        let masterSet = Set(master.locations)

        for type in SoundingSelection.ModelType.allCases {
            let perType = try LocationList.forType(type)
            for loc in perType.locations {
                XCTAssertTrue(masterSet.contains(loc),
                              "allLocations is missing \(loc) (from \(type))")
            }
        }

        XCTAssertEqual(master.locations.count, masterSet.count,
                       "allLocations contains duplicates")
    }
    
    func testLocationSearching() throws {
        let list = LocationList.allLocations
        
        XCTAssertEqual(list.locationsForSearch("IAD").first?.name, "IAD")
        XCTAssertEqual(list.locationsForSearch("KIAD").first?.name, "IAD")
        XCTAssertEqual(list.locationsForSearch("Dulle").first?.name, "IAD")
        XCTAssertEqual(list.locationsForSearch("SAN").first?.name, "SAN")
        XCTAssertEqual(list.locationsForSearch("SFO").first?.name, "SFO")
        XCTAssertEqual(list.locationsForSearch("San Fr").first?.name, "SFO")
    }
}
