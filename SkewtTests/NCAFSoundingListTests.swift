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
    @Test("Temperature group parsing")
    func parseTemperatureGroups() throws {
        // Omitted values
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "/////")!.temperature == nil)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "/////")!.dewPoint == nil)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "200//")!.temperature == 20.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "200//")!.dewPoint == nil)

        // Temperatures
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "00000")!.temperature == 0.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "20000")!.temperature == 20.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "20100")!.temperature == -20.1)

        // Dew point depressions as hundreds
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30000")!.dewPoint == 30.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30002")!.dewPoint == 29.8)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30043")!.dewPoint == 25.7)
        
        // Dew point depressions as ones
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30050")!.dewPoint == 25.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30056")!.dewPoint == 24.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30062")!.dewPoint == 18.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30075")!.dewPoint == 5.0)
        #expect(NCAFSoundingMessage.TemperatureGroup(fromString: "30080")!.dewPoint == 0.0)
    }
    
    @Test("Wind group parsing")
    func parseWind() throws {
        // Normal values
        #expect(NCAFSoundingMessage.WindGroup(fromString: "/////")!.direction == nil)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "/////")!.speed == nil)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "09010")!.direction == 90)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "09010")!.speed == 10)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "22532")!.direction == 225)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "22532")!.speed == 32)

        // Other-than-0/5 wind directions meaning 100+ wind speed
        #expect(NCAFSoundingMessage.WindGroup(fromString: "22632")!.direction == 225)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "22632")!.speed == 132)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "22732")!.direction == 225)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "22732")!.speed == 232)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "09112")!.direction == 90)
        #expect(NCAFSoundingMessage.WindGroup(fromString: "09112")!.speed == 112)
    }
    
    @Test("Pressure group parsing")
    func parsePressure() throws {
        // Surface pressure
        #expect(NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "99008")!.isSurface)
        #expect(NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "99008")!.pressure == 1008.0)
        
        // Require height for surface
        #expect(NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "99///") == nil)
        
        // Mandatory level pressures
        let pressure00151 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "00151")!
        #expect(pressure00151.pressure == 1000.0)
        #expect(pressure00151.height == 151)
        let pressure00088 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "00088")!
        #expect(pressure00088.pressure == 1000.0)
        #expect(pressure00088.height == 88)
        let pressure00120 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "00120")!
        #expect(pressure00120.pressure == 1000.0)
        #expect(pressure00120.height == 120)
        let pressure92818 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "92818")!
        #expect(pressure92818.pressure == 925.0)
        #expect(pressure92818.height == 818)
        let pressure92791 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "92791")!
        #expect(pressure92791.pressure == 925.0)
        #expect(pressure92791.height == 791)
        let pressure92762 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "92762")!
        #expect(pressure92762.pressure == 925.0)
        #expect(pressure92762.height == 762)
        let pressure85529 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "85529")!
        #expect(pressure85529.pressure == 850.0)
        #expect(pressure85529.height == 1529)
        let pressure85456 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "85456")!
        #expect(pressure85456.pressure == 850.0)
        #expect(pressure85456.height == 1456)
        let pressure85612 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "85612")!
        #expect(pressure85612.pressure == 850.0)
        #expect(pressure85612.height == 1612)
        let pressure85508 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "85508")!
        #expect(pressure85508.pressure == 850.0)
        #expect(pressure85508.height == 1508)
        let pressure70108 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "70108")!
        #expect(pressure70108.pressure == 700.0)
        #expect(pressure70108.height == 3108)
        let pressure70023 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "70023")!
        #expect(pressure70023.pressure == 700.0)
        #expect(pressure70023.height == 3023)
        let pressure70189 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "70189")!
        #expect(pressure70189.pressure == 700.0)
        #expect(pressure70189.height == 3189)
        let pressure50575 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "50575")!
        #expect(pressure50575.pressure == 500.0)
        #expect(pressure50575.height == 5750)
        let pressure50548 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "50548")!
        #expect(pressure50548.pressure == 500.0)
        #expect(pressure50548.height == 5480)
        let pressure50621 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "50621")!
        #expect(pressure50621.pressure == 500.0)
        #expect(pressure50621.height == 6210)
        let pressure40740 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "40740")!
        #expect(pressure40740.pressure == 400.0)
        #expect(pressure40740.height == 7400)
        let pressure30941 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "30941")!
        #expect(pressure30941.pressure == 300.0)
        #expect(pressure30941.height == 9410)
        let pressure25060 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "25060")!
        #expect(pressure25060.pressure == 250.0)
        #expect(pressure25060.height == 10600)
        let pressure20205 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "20205")!
        #expect(pressure20205.pressure == 200.0)
        #expect(pressure20205.height == 12050)
        let pressure20123 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "20123")!
        #expect(pressure20123.pressure == 200.0)
        #expect(pressure20123.height == 11230)
        let pressure15391 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "15391")!
        #expect(pressure15391.pressure == 150.0)
        #expect(pressure15391.height == 13910)
        let pressure15234 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "15234")!
        #expect(pressure15234.pressure == 150.0)
        #expect(pressure15234.height == 12340)
        let pressure15789 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "15789")!
        #expect(pressure15789.pressure == 150.0)
        #expect(pressure15789.height == 17890)
        let pressure10649 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "10649")!
        #expect(pressure10649.pressure == 100.0)
        #expect(pressure10649.height == 16490)
        let pressure10234 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "10234")!
        #expect(pressure10234.pressure == 100.0)
        #expect(pressure10234.height == 12340)
        let pressure10567 = NCAFSoundingMessage.PressureGroup(fromMandatoryLevelString: "10567")!
        #expect(pressure10567.pressure == 100.0)
        #expect(pressure10567.height == 15670)
        
        // TODO: Add negative MSL height
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
        
        let message = NCAFSoundingMessage(fromString: s)
        #expect(message != nil)

        let surface = message!.levels.first { levelType, _ in
            levelType == .surface
        }?.value
        #expect(surface != nil)
        #expect(abs(surface!.pressureGroup!.pressure - 1008.0) <= tolerance)
        #expect(abs(surface!.temperatureGroup!.temperature! - 18.4) <= tolerance)
        #expect(abs(surface!.temperatureGroup!.dewPoint! - 17.7) <= tolerance)
        #expect(surface!.windGroup!.direction == 350)
        #expect(surface!.windGroup!.speed! == 4)
        
        let at925 = message!.levels.first { levelType, _ in
            levelType == .mandatory(925.0)
        }?.value
        #expect(at925 != nil)
        #expect(abs(at925!.temperatureGroup!.temperature! - 15.0) <= tolerance)
        #expect(abs(at925!.temperatureGroup!.dewPoint! - 13.8) <= tolerance)
        #expect(at925!.windGroup!.direction == 35)
        #expect(at925!.windGroup!.speed! == 10)
    }
//    
//    @Test("Significant level data is parsed")
//    func parseSignificantLevel() throws {
//        let tolerance = 0.0001
//        let s = """
//            72518  TTBB 69120 72518 00008 18407 11980 17005 22951 17010
//            33897 12805 44850 11034 55831 12050 66758 09857 77726 07218
//            88712 07065 99666 04458 11645 02249 22521 07562 33491 08972
//            44372 24567 55367 25143 66358 26513 77349 26956 88332 29558
//            99295 36731 11265 42959 22200 57758 33100 61360 31313 01102
//            81106=
//            """
//        
//        let list = try NCAFSoundingList(fromString: s)
//        let sounding = list.dataByStationId[72518]
//        #expect(sounding != nil)
//        
//        let data = sounding!.data
//        #expect(!data.dataPoints.isEmpty)
//        
//        let surfaceData = data.surfaceDataPoint!
//        #expect(abs(surfaceData.pressure - 1008.0) <= tolerance)
//        #expect(abs(surfaceData.temperature! - 18.4) <= tolerance)
//        #expect(abs(surfaceData.dewPoint! - 17.7) <= tolerance)
//        
//        let at980 = data.dataPoints.filter({ $0.pressure == 980.0 }).first!
//        #expect(abs(at980.temperature! - 17.0) <= tolerance)
//        #expect(abs(at980.dewPoint! - 16.5) <= tolerance)
//        
//        let at951 = data.dataPoints.filter({ $0.pressure == 951.0 }).first!
//        #expect(abs(at951.temperature! - 17.0) <= tolerance)
//        #expect(abs(at951.dewPoint! - 16.0) <= tolerance)
//    }
//    
    @Test("Entire Current.rawins file parses without failure")
    func parseCurrentRawins() throws {
        let bundle = Bundle(for: NCAFSoundingListTestClass.self)
        let fileUrl = bundle.url(forResource: "Current", withExtension: "rawins")!
        let data = try Data(contentsOf: fileUrl)
        let string = String(data: data, encoding: .utf8)!
        
        let list = try NCAFSoundingList(fromString: string)
        print("woo")
    }
//    
//    // TODO: Test negative geopotential height
}
