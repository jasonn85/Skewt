//
//  SkewtTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 2/15/23.
//

import XCTest
@testable import Skewt

extension Sounding {
    init(withJustData data: [LevelDataPoint]) throws {
        self.init(
            stationInfo: try StationInfo(fromText: "      1  23062  72290  32.78 117.06      9  99999"),
            type: .op40,
            timestamp: Date(timeIntervalSince1970: 1693945305),
            description: "Test data",
            stationId: "0",
            windSpeedUnit: .kt,
            radiosondeCode: nil,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil,
            data: data
        )
    }
}

class SkewtTests: XCTestCase {
    func testNilSentinel() {
        XCTAssertEqual(Int(fromSoundingString: "69"), 69)
        XCTAssertEqual(Int(fromSoundingString: "-5785"), -5785)
        XCTAssertEqual(Double(fromSoundingString: "3.14159"), 3.14159)
        XCTAssertNil(Int(fromSoundingString: "99999"), "99999 is recognized as a nil value")
        XCTAssertNil(Double(fromSoundingString: "99999"), "99999 is recognized as a nil value")
        XCTAssertNil(Int(fromSoundingString: "  99999"), "99999 with leading whitespace is recognized as nil")
    }
    
    func testSoundingDataColumnSlicing() {
        let varLine = "   CAPE      0    CIN      0  Helic  99999     PW  99999"
        let varLineColumns = varLine.soundingColumns()
        XCTAssertEqual(varLineColumns[0], "   CAPE")
        XCTAssertEqual(varLineColumns[7], "  99999")
        
        let normalLine = "      1  23062  72290  32.78 117.06      9  99999"
        let normalLineColumns = normalLine.soundingColumns()
        XCTAssertEqual(normalLineColumns[0], "      1")
        XCTAssertEqual(normalLineColumns[3], "  32.78")
        
        let lineWithBlanks = "      3           SAN                   12     kt"
        let lineWithBlanksColumns = lineWithBlanks.soundingColumns()
        XCTAssertEqual(lineWithBlanksColumns[0], "      3")
        XCTAssertTrue(lineWithBlanksColumns[1].trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertEqual(lineWithBlanksColumns[5], "     12")
    }
    
    func testSoundingDataTypeAndDataParsing() throws {
        let lineWithBlanks = "      3           SAN                   12     kt"
        let (lineWithBlanksType, lineWithBlanksColumns) = try lineWithBlanks.soundingTypeAndColumns()
        XCTAssertEqual(lineWithBlanksType, .stationIdAndOther)
        XCTAssertEqual(lineWithBlanksColumns[1], "    SAN")
        
        let normalLine = "      5   9852    304    117    -55    289      7"
        let (normalLineType, normalLineColumns) = try normalLine.soundingTypeAndColumns()
        XCTAssertEqual(normalLineType, .significantLevel)
        XCTAssertEqual(normalLineColumns[3], "    -55")
        
        let unknownTypeLine = "     69   1234"
        do {
            let (_, _) = try unknownTypeLine.soundingTypeAndColumns()
            XCTFail("Unrecognized line type should throw an error")
        } catch SoundingParseError.unparseableLine {
            return
        } catch {
            XCTFail("Unrecognized line type should throw a SoundingParseError.unparseableLine")
        }
    }
    
    func testDateParsing() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let dateLine = "Op40        22     15      Feb    2023"
        let date = try dateLine.dateFromHeaderLine()
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        XCTAssertEqual(dateComponents.year, 2023)
        XCTAssertEqual(dateComponents.month, 2)
        XCTAssertEqual(dateComponents.day, 15)
        XCTAssertEqual(dateComponents.hour, 22)
        
        let notADate = "Op40     cheese tastes cheesy weezy"
    
        do {
            let _ = try notADate.dateFromHeaderLine()
            XCTFail("A non-date should throw an error when parsed as a date")
        } catch SoundingParseError.unparseableLine {
            return
        } catch {
            XCTFail("A non-date should throw a SoundingParseError.unparseableLine when parsed as a date")
        }
    }
    
    func testLineFiltering() {
        let stationIdLine = "      1  23062  72290  32.78 117.06      9  99999"
        let stationAndOthersLine = "      3           DEN                   12     kt"
        let mandatoryLineWithBlanks = "      4   8500  99999  99999  99999  99999  99999"
        let mandatoryLine = "      4   2500  10313   -525   -574    256     36"
        let significantLine = "      5   2331  10762   -553   -602    235     36"
        let surfaceLine = "      9  10031    146    138    -50    287      7"
        let garbageLine = "what a silly way to spend your time"
        
        let all = [stationIdLine, stationAndOthersLine, mandatoryLineWithBlanks,
                   mandatoryLine, significantLine, surfaceLine, garbageLine]
        
        XCTAssertEqual(all.filter(byDataTypes: [.stationId]), [stationIdLine])
        XCTAssertEqual(all.filter(byDataTypes: [.stationIdAndOther]), [stationAndOthersLine])
        XCTAssertEqual(all.filter(byDataTypes: [.mandatoryLevel, .significantLevel, .surfaceLevel]),
                       [mandatoryLineWithBlanks, mandatoryLine, significantLine, surfaceLine])
    }
    
    func testStationInfoParsing() throws {
        let stationInfo = try StationInfo(fromText: "      1  23062  72290  32.78 117.06      9  99999")
        XCTAssertEqual(stationInfo.wbanId, 23062)
        XCTAssertEqual(stationInfo.wmoId, 72290)
        XCTAssertEqual(stationInfo.latitude, 32.78)
        XCTAssertEqual(stationInfo.longitude, -117.06)
        XCTAssertEqual(stationInfo.altitude, 9)
        
        // Lat/long mushed together like happens with ROAB data
        let mushedInfo = try StationInfo(fromText: "      1   3190  72293  32.87N117.15W   134   1103")
        XCTAssertEqual(mushedInfo.wbanId, 3190)
        XCTAssertEqual(mushedInfo.wmoId, 72293)
        XCTAssertEqual(mushedInfo.latitude, 32.87)
        XCTAssertEqual(mushedInfo.longitude, -117.15)
        XCTAssertEqual(mushedInfo.altitude, 134)
        
        // Permit missing WMO ID and altitude
        let stationInfoNoWmoIdOrAltitude = try StationInfo(fromText: "      1  23062  99999  32.87 117.15  99999  99999")
        XCTAssertEqual(stationInfoNoWmoIdOrAltitude.wbanId, 23062)
        XCTAssertNil(stationInfoNoWmoIdOrAltitude.wmoId)
        XCTAssertEqual(stationInfoNoWmoIdOrAltitude.latitude, 32.87)
        XCTAssertEqual(stationInfoNoWmoIdOrAltitude.longitude, -117.15)
        XCTAssertNil(stationInfoNoWmoIdOrAltitude.altitude)
        
        do {
            let _ = try StationInfo(fromText: "      4   2500  10313   -525   -574    256     36")
            XCTFail("Parsing a data point line as a station ID line should throw an error")
        } catch SoundingParseError.lineTypeMismatch {
            return
        } catch {
            XCTFail("Parsing a data point line as a station ID line should throw a "
                    + "SoundingParseError.lineTypeMismatch")
        }
        
        let line = "      3           SAN                   12     kt"
        let stationInfoAndOther = try StationInfoAndOther(fromText: line)
        XCTAssertEqual(stationInfoAndOther.stationId, "SAN")
        XCTAssertEqual(stationInfoAndOther.radiosondeType, .sdc)
        XCTAssertEqual(stationInfoAndOther.windSpeedUnit, .kt)
        
        do {
            let _ = try StationInfoAndOther(fromText: "      4   2500  10313   -525   -574    256     36")
            XCTFail("Parsing a data point line as a station ID and others line should throw an error")
        } catch SoundingParseError.lineTypeMismatch {
            return
        } catch {
            XCTFail("Parsing a data point line as a station ID and others line should throw a "
                    + " SoundingParseError.lineTypeMismatch")
        }
    }
    
    func testDataPointParsing() throws {
        let mandatoryLine = "      4   2500  10313   -525   -574    256     36"
        let mandatory = try LevelDataPoint(fromText: mandatoryLine)
        XCTAssertEqual(mandatory.type, .mandatoryLevel)
        XCTAssertEqual(mandatory.pressure, 250.0)
        XCTAssertEqual(mandatory.height, 10313)
        XCTAssertEqual(mandatory.temperature, -52.5)
        XCTAssertEqual(mandatory.dewPoint, -57.4)
        XCTAssertEqual(mandatory.windDirection, 256)
        XCTAssertEqual(mandatory.windSpeed, 36)
        
        let significantLine = "      5   2331  10762   -553   -602    235     36"
        let significant = try LevelDataPoint(fromText: significantLine)
        XCTAssertEqual(significant.type, .significantLevel)
        XCTAssertEqual(significant.pressure, 233.1)
        XCTAssertEqual(significant.height, 10762)
        XCTAssertEqual(significant.temperature, -55.3)
        XCTAssertEqual(significant.dewPoint, -60.2)
        XCTAssertEqual(significant.windDirection, 235)
        XCTAssertEqual(significant.windSpeed, 36)
        
        let mandatoryLineWithBlanks = "      4   8500  99999  99999  99999  99999  99999"
        let blanks = try LevelDataPoint(fromText: mandatoryLineWithBlanks)
        XCTAssertEqual(blanks.type, .mandatoryLevel)
        XCTAssertEqual(blanks.pressure, 850.0)
        XCTAssertNil(blanks.temperature)
        XCTAssertNil(blanks.dewPoint)
        XCTAssertNil(blanks.windDirection)
        XCTAssertNil(blanks.windSpeed)
        
        let windLine = "      6    262  24384  99999  99999     40     10   1235     88     90"
        let wind = try LevelDataPoint(fromText: windLine)
        XCTAssertEqual(wind.type, .windLevel)
        XCTAssertNil(wind.temperature)
        XCTAssertNil(wind.dewPoint)
        XCTAssertEqual(wind.windDirection, 40)
        XCTAssertEqual(wind.windSpeed, 10)
        
        let stationIdLine = "      1  23062  72290  32.78 117.06      9  99999"
        do {
            let _ = try LevelDataPoint(fromText: stationIdLine)
            XCTFail("Parsing a station ID line as a data point should throw an error")
        } catch SoundingParseError.lineTypeMismatch {
            return
        } catch {
            XCTFail("Parsing a station ID line as a data point should throw a SoundingParseError.lineTypeMismatch")
        }
    }
    
    func testOp40Parsing() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "san-op40-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        let lines = s.components(separatedBy: .newlines)
        
        let sounding = try Sounding(fromText: s)
        XCTAssertEqual(sounding.type, .op40)
        XCTAssertEqual(sounding.description, "Op40 analysis valid for grid point 6.9 nm / 66 deg from SAN:")
        XCTAssertEqual(sounding.data.count, 62)
        XCTAssertEqual(sounding.data.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 62)
        XCTAssertEqual(sounding.data.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 62)
        XCTAssertEqual(sounding.stationId, "SAN")
        XCTAssertEqual(sounding.cape, 0)
        XCTAssertEqual(sounding.cin, 0)
        
        let linesMinusGlobals = lines[0...1] + lines[3...]
        let minusGlobals = linesMinusGlobals.joined(separator: "\n")
        let _ = try Sounding(fromText: minusGlobals)
        
        let linesMinusHeader = [lines[0]] + lines[2...]
        let missingHeader = linesMinusHeader.joined(separator: "\n")
        
        do {
            let _ = try Sounding(fromText: missingHeader)
            XCTFail("Parsing a sounding with no header should throw an error")
        } catch SoundingParseError.missingHeaders {
            return
        } catch {
            XCTFail("Parsing a sounding with no header should throw a SoundingParseError.missingHeaders, "
                    + "not a \(String(describing: error))")
        }
    }
    
    func testRaobParsing() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "nkx-raob-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!

        let sounding = try Sounding(fromText: s)
        XCTAssertEqual(sounding.type, .raob)
        XCTAssertEqual(sounding.description, "RAOB sounding valid at:")
        XCTAssertEqual(sounding.data.count, 231)
        XCTAssertEqual(sounding.data.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 89)
        XCTAssertEqual(sounding.data.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 162)
        XCTAssertEqual(sounding.stationId, "NKX")
    }
    
    func testNamParsing() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "iad-nam-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        
        let sounding = try Sounding(fromText: s)
        XCTAssertEqual(sounding.type, .nam)
        XCTAssertEqual(sounding.description, "NAM analysis valid for grid point 8.8 nm / 330 deg from IAD:")
        XCTAssertEqual(sounding.stationId, "IAD")
        XCTAssertEqual(sounding.cape, 0)
        XCTAssertEqual(sounding.cin, 0)
        XCTAssertEqual(sounding.data.count, 39)
        XCTAssertEqual(sounding.data.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 39)
        XCTAssertEqual(sounding.data.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 39)
    }
    
    func testGfsParsing() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "ord-gfs-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        
        let sounding = try Sounding(fromText: s)
        XCTAssertEqual(sounding.type, .gfs)
        XCTAssertEqual(sounding.description, "GFS analysis valid for grid point 4.6 nm / 285 deg from ORD:")
        XCTAssertEqual(sounding.stationId, "ORD")
        XCTAssertEqual(sounding.cape, 0)
        XCTAssertEqual(sounding.cin, 0)
        XCTAssertEqual(sounding.data.count, 31)
        XCTAssertEqual(sounding.data.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 26)
        XCTAssertEqual(sounding.data.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 31)
    }
    
    func testGlobalsParsing() {
        let a = "   CAPE      0    CIN      0  Helic  99999     PW  99999".globals()
        XCTAssertEqual(a["CAPE"], 0)
        XCTAssertEqual(a["CIN"], 0)
        XCTAssertNil(a["Helic"])
        XCTAssertNil(a["PW"])
        
        let b = "   CAPE    170    CIN      1  Helic  99999     PW  99999".globals()
        XCTAssertEqual(b["CAPE"], 170)
        XCTAssertEqual(b["CIN"], 1)
    }

    func testNearestValue() throws {
        let temperaturesAndPressures = [(-20.0, 1000.0), (-10.0, 900.0), (0.0, 800.0), (10.0, 700.0), (20.0, 600.0)]
        let dewPointSpread = 10.0
        
        let points = temperaturesAndPressures.map {
            LevelDataPoint(
                type: .significantLevel,
                pressure: $0.1,
                height: nil,
                temperature: $0.0,
                dewPoint: $0.0 - dewPointSpread,
                windDirection: nil,
                windSpeed: nil
            )
        }
        
        let sounding = try Sounding(withJustData: Array(points))

        XCTAssertEqual(
            sounding.closestValue(toPressure: temperaturesAndPressures[0].1, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures[0].0,
            "Closest value to first value is first value"
        )
        
        XCTAssertEqual(
            sounding.closestValue(toPressure: 1500.0, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures[0].0,
            "Closest value to underground is first value"
        )
        
        XCTAssertEqual(
            sounding.closestValue(toPressure: temperaturesAndPressures.last!.1, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures.last!.0,
            "Closest value to last value is last value"
        )
        
        XCTAssertEqual(
            sounding.closestValue(toPressure: 0.0, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures.last!.0,
            "Closest value to space is last value"
        )
        
        let closerToTwoThanThreePressure = (temperaturesAndPressures[2].1 
                                            + temperaturesAndPressures[2].1
                                            + temperaturesAndPressures[3].1) / 3.0
        XCTAssertEqual(
            sounding.closestValue(toPressure: closerToTwoThanThreePressure, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures[2].0,
            "A pressure closer to entry #2 than #3 results in #2"
        )
    }
    
    func testInterpolation() throws {
        let temperaturesAndPressures = [(-20.0, 1000.0), (-10.0, 900.0), (0.0, 800.0), (10.0, 700.0), (20.0, 600.0)]
        let dewPointSpread = 10.0
        
        let points = temperaturesAndPressures.map {
            LevelDataPoint(
                type: .significantLevel,
                pressure: $0.1,
                height: nil,
                temperature: $0.0,
                dewPoint: $0.0 - dewPointSpread,
                windDirection: nil,
                windSpeed: nil
            )
        }
    
        let sounding = try Sounding(withJustData: Array(points))
        
        XCTAssertEqual(
            sounding.interpolatedValue(for: \.temperature, atPressure: temperaturesAndPressures[0].1),
            points[0].temperature,
            "Interpolation returns exact match if one exists"
        )
        XCTAssertEqual(
            sounding.interpolatedValue(for: \.temperature, atPressure: temperaturesAndPressures[4].1),
            points[4].temperature,
            "Interpolation returns exact match if one exists"
        )
        XCTAssertEqual(
            sounding.interpolatedValue(for: \.dewPoint, atPressure: temperaturesAndPressures[0].1),
            points[0].dewPoint,
            "Interpolation returns exact match if one exists"
        )
        
        let hopefullyFive = sounding.interpolatedValue(
            for: \.temperature,
            atPressure: (temperaturesAndPressures[2].1 + temperaturesAndPressures[3].1) / 2.0
        )
        XCTAssertNotNil(hopefullyFive)
        XCTAssertTrue(hopefullyFive! > temperaturesAndPressures[2].0)
        XCTAssertTrue(hopefullyFive! < temperaturesAndPressures[3].0)
        
        let hopefullyNegativeFifteen = sounding.interpolatedValue(
            for: \.temperature,
            atPressure: (temperaturesAndPressures[0].1 + temperaturesAndPressures[1].1) / 2.0
        )
        XCTAssertNotNil(hopefullyNegativeFifteen)
        XCTAssertTrue(hopefullyNegativeFifteen! > temperaturesAndPressures[0].0)
        XCTAssertTrue(hopefullyNegativeFifteen! < temperaturesAndPressures[1].0)
    }
}
