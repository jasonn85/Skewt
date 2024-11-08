//
//  OpenMeteoTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 11/6/24.
//

import Testing
import Foundation
@testable import Skewt

class OpenMeteoTests {
    @Test("An Open Meteo response with 10 results (UTC timestamps) parses into 10 soundings")
    func parseMultipleSoundings() throws {
        let bundle = Bundle(for: OpenMeteoTests.self)
        let fileUrl = bundle.url(forResource: "open-meteo", withExtension: "json")!
        let data = try Data(contentsOf: fileUrl)
        
        let result = try OpenMeteoSoundingList(fromData: data)
        #expect(result.data.count == 24)
    }
    
    @Test("ISO 8601 timestamp in Open Meteo soundings list is parsed")
    func isoDate() throws {
        
    }
}
