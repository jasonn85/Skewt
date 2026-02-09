//
//  NCAFSoundingListTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 2/8/26.
//

import Testing
import Foundation
@testable import Skewt

final class NCAFSoundingListTestClass {}

struct NCAFSoundingListTests {
    @Test("Temperature block parsing")
    func parseTemperatureBlocks() throws {
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "00000").0 == 0.0)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "20000").0 == 20.0)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "20100").0 == -20.1)
        
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30000").1 == 30.0)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30002").1 == 29.8)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30043").1 == 25.7)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30050").1 == 25.0)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30056").1 == 24.0)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30062").1 == 18.0)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30075").1 == 5.0)
        #expect(try NCAFSoundingList.temperatureAndDewPoint(fromString: "30080").1 == 0.0)
    }
    
    @Test("Wind block parsing")
    func parseWind() throws {
        // Normal values
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "09010").0 == 90)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "09010").1 == 10.0)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "22532").0 == 225)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "22532").1 == 32.0)
        
        // Other-than-0/5 wind directions meaning 100+ wind speed
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "22632").0 == 225)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "22632").1 == 132.0)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "22732").0 == 225)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "22732").1 == 232.0)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "09112").0 == 90)
        #expect(try NCAFSoundingList.windSpeedAndDirection(fromString: "09112").1 == 112.0)
    }
    
    @Test("Mandatory level data is parsed")
    func parseMandatoryLevel() throws {
        let tolerance = 0.0001
        let s = """
            72518  TTAA 69121 72518 99008 18407 35004 00151 18208 36007
            92818 15012 03510 85529 11034 04510 70142 06262 35005 50582
            08770 23006 40752 20569 22532 30958 35737 22563 25082 46359
            23568 20226 57758 22572 15407 59159 23552 10660 61360 24518
            88176 59758 22574 77181 22576 41218 51515 10164 00008 10194
            03011 02006=
            """

        let list = try NCAFSoundingList(fromString: s)
        let sounding = list.dataByStationId[72518]
        #expect(sounding != nil)

        let data = sounding!.data
        #expect(!data.dataPoints.isEmpty)
        
        let surfaceData = data.surfaceDataPoint!
        #expect(abs(surfaceData.pressure - 1008.0) <= tolerance)
        #expect(abs(surfaceData.temperature! - 18.4) <= tolerance)
        #expect(abs(surfaceData.dewPoint! - 17.7) <= tolerance)
        #expect(surfaceData.windDirection == 350)
        #expect(abs(surfaceData.windSpeed! - 4.0) <= tolerance)
        
        let at925 = data.dataPoints.filter({ $0.pressure == 925.0 }).first!
        #expect(abs(at925.temperature! - 15.0) <= tolerance)
        #expect(abs(at925.dewPoint! - 13.8) <= tolerance)
        #expect(at925.windDirection == 35)
        #expect(abs(at925.windSpeed! - 10.0) <= tolerance)
    }
    
    @Test("Significant level data is parsed")
    func parseSignificantLevel() throws {
        let tolerance = 0.0001
        let s = """
            72518  TTBB 69120 72518 00008 18407 11980 17005 22951 17010
            33897 12805 44850 11034 55831 12050 66758 09857 77726 07218
            88712 07065 99666 04458 11645 02249 22521 07562 33491 08972
            44372 24567 55367 25143 66358 26513 77349 26956 88332 29558
            99295 36731 11265 42959 22200 57758 33100 61360 31313 01102
            81106=
            """
        
        let list = try NCAFSoundingList(fromString: s)
        let sounding = list.dataByStationId[72518]
        #expect(sounding != nil)
        
        let data = sounding!.data
        #expect(!data.dataPoints.isEmpty)
        
        let surfaceData = data.surfaceDataPoint!
        #expect(abs(surfaceData.pressure - 1008.0) <= tolerance)
        #expect(abs(surfaceData.temperature! - 18.4) <= tolerance)
        #expect(abs(surfaceData.dewPoint! - 17.7) <= tolerance)
        
        let at980 = data.dataPoints.filter({ $0.pressure == 980.0 }).first!
        #expect(abs(at980.temperature! - 17.0) <= tolerance)
        #expect(abs(at980.dewPoint! - 16.5) <= tolerance)
        
        let at951 = data.dataPoints.filter({ $0.pressure == 951.0 }).first!
        #expect(abs(at951.temperature! - 17.0) <= tolerance)
        #expect(abs(at951.dewPoint! - 16.0) <= tolerance)
    }
    
    // TODO: Test negative geopotential height
}
