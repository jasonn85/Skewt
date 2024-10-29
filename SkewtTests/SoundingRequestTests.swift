//
//  SoundingRequestTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 5/18/23.
//

import XCTest
@testable import Skewt

final class SoundingRequestTests: XCTestCase {
    func testBaseUrl() {
        let request = SoundingRequest(location: .name("NKX"))
        let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(components.scheme!, "https")
        XCTAssertEqual(components.host!, "rucsoundings.noaa.gov")
        XCTAssertEqual(components.path, "/get_soundings.cgi")
    }
    
    func testNamedLocation() {
        let locationName = "NKX&SAN"  // Nonsensical location name but tests URL escaping
        let request = SoundingRequest(location: .name(locationName))
        let url = request.url
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let item = components!.queryItems!.first { $0.name == "airport" }!
        XCTAssertEqual(item.value, locationName)
    }
    
    func testCoordinateLocation() {
        let coords = (32.85, -117.12)
        let location = SoundingRequest.Location.geolocation(latitude: coords.0, longitude: coords.1)
        let request = SoundingRequest(location: location)
        let url = request.url
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let item = components!.queryItems!.first { $0.name == "airport" }!
        XCTAssertEqual(item.value, "\(String(coords.0)),\(String(coords.1))")
    }
    
    func testLocationDecimalPlaces() {
        let coords2 = (32.85, -117.12)
        let coords1 = (32.9, -117.1)
        let coords0 = (33, -117)
        let location = SoundingRequest.Location.geolocation(latitude: coords2.0, longitude: coords2.1)

        let formatter2 = SoundingRequestLocationFormatter(numberOfDecimals: 2)
        XCTAssertEqual(formatter2.string(forLocation: location), "\(String(coords2.0)),\(String(coords2.1))")
        let formatter1 = SoundingRequestLocationFormatter(numberOfDecimals: 1)
        XCTAssertEqual(formatter1.string(forLocation: location), "\(String(coords1.0)),\(String(coords1.1))")
        let formatter0 = SoundingRequestLocationFormatter(numberOfDecimals: 0)
        XCTAssertEqual(formatter0.string(forLocation: location), "\(String(coords0.0)),\(String(coords0.1))")
    }
    
    func testModelTypes() {
        let location = SoundingRequest.Location.name("NKX")
    
        RucSounding.SoundingType.allCases.forEach {
            let request = SoundingRequest(location: location, modelName: $0)
            let urlComponents = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!
            let modelQueryItem = urlComponents.queryItems!.first { $0.name == "data_source" }!
            XCTAssertEqual(modelQueryItem.value, $0.rawValue)
        }
    }
    
    func testLatestOrStartTime() {
        let startTimeEpoch = TimeInterval(1683417600)
        let startTime = Date(timeIntervalSince1970: startTimeEpoch)
        
        let timeRequest = SoundingRequest(location: .name("NKX"), startTime: startTime)
        let timeComponents = URLComponents(url: timeRequest.url, resolvingAgainstBaseURL: false)!
        let timeItem = timeComponents.queryItems!.first { $0.name == "startSecs" }!
        XCTAssertEqual(String(timeItem.value!), String(Int(startTimeEpoch)))
        XCTAssertNil(timeComponents.queryItems!.first { $0.name == "start" })
        
        let nowRequest = SoundingRequest(location: .name("NKX"))
        let nowComponents = URLComponents(url: nowRequest.url, resolvingAgainstBaseURL: false)!
        XCTAssertNil(nowComponents.queryItems!.first { $0.name == "startSecs" })
        XCTAssertEqual(nowComponents.queryItems!.first { $0.name == "start" }!.value , "latest")
    }
    
    func testTimestamps() {
        let startTimeEpoch = TimeInterval(1683417600)
        let endTimeEpoch = TimeInterval(1683504000)
        let startTime = Date(timeIntervalSince1970: startTimeEpoch)
        let endTime = Date(timeIntervalSince1970: endTimeEpoch)
        
        let request = SoundingRequest(location: .name("NKX"), startTime: startTime, endTime: endTime)
        let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!
        let startQueryItem = components.queryItems!.first { $0.name == "startSecs" }!
        let endQueryItem = components.queryItems!.first { $0.name == "endSecs" }!
        
        XCTAssertEqual(String(startQueryItem.value!), String(Int(startTimeEpoch)))
        XCTAssertEqual(String(endQueryItem.value!), String(Int(endTimeEpoch)))
    }
    
    func testNumberOfHours() {
        let location = SoundingRequest.Location.name("NKX")
        
        stride(from: 1, to: 12, by: 1).forEach {
            let request = SoundingRequest(location: location, numberOfHours: $0)
            let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!
            let queryItem = components.queryItems!.first { $0.name == "n_hrs" }!
            XCTAssertEqual(queryItem.value, String($0))
        }
    }
}
