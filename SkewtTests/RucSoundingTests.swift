//
//  RucSoundingTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 2/15/23.
//

import XCTest
@testable import Skewt

extension RucSounding {
    init(withJustData data: [RucSounding.LevelDataPoint]) throws {
        let points = data.map { SoundingData.Point(
            pressure: $0.pressure,
            height: $0.height != nil ? Double($0.height!) : nil,
            temperature: $0.temperature,
            dewPoint: $0.dewPoint,
            windDirection: $0.windDirection,
            windSpeed: $0.windSpeed != nil ? Double($0.windSpeed!) : nil
        ) }
        
        self.init(
            stationInfo: try StationInfo(fromText: "      1  23062  72290  32.78 117.06      9  99999"),
            type: .op40,
            description: "Test data",
            stationId: "0",
            windSpeedUnit: .kt,
            radiosondeCode: nil,
            data: SoundingData(
                time: Date(timeIntervalSince1970: 1693945305),
                elevation: 0,
                dataPoints: points,
                surfaceDataPoint: points.first,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )
        )
    }
}

class RucSoundingTests: XCTestCase {
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
        } catch RucSounding.ParseError.unparseableLine {
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
        } catch RucSounding.ParseError.unparseableLine {
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
        let stationInfo = try RucSounding.StationInfo(fromText: "      1  23062  72290  32.78 117.06      9  99999")
        XCTAssertEqual(stationInfo.wbanId, 23062)
        XCTAssertEqual(stationInfo.wmoId, 72290)
        XCTAssertEqual(stationInfo.latitude, 32.78)
        XCTAssertEqual(stationInfo.longitude, -117.06)
        XCTAssertEqual(stationInfo.altitude, 9)
        
        // Lat/long mushed together like happens with ROAB data
        let mushedInfo = try RucSounding.StationInfo(fromText: "      1   3190  72293  32.87N117.15W   134   1103")
        XCTAssertEqual(mushedInfo.wbanId, 3190)
        XCTAssertEqual(mushedInfo.wmoId, 72293)
        XCTAssertEqual(mushedInfo.latitude, 32.87)
        XCTAssertEqual(mushedInfo.longitude, -117.15)
        XCTAssertEqual(mushedInfo.altitude, 134)
        
        // Permit missing WMO ID and altitude
        let stationInfoNoWmoIdOrAltitude = try RucSounding.StationInfo(fromText: "      1  23062  99999  32.87 117.15  99999  99999")
        XCTAssertEqual(stationInfoNoWmoIdOrAltitude.wbanId, 23062)
        XCTAssertNil(stationInfoNoWmoIdOrAltitude.wmoId)
        XCTAssertEqual(stationInfoNoWmoIdOrAltitude.latitude, 32.87)
        XCTAssertEqual(stationInfoNoWmoIdOrAltitude.longitude, -117.15)
        XCTAssertNil(stationInfoNoWmoIdOrAltitude.altitude)
        
        do {
            let _ = try RucSounding.StationInfo(fromText: "      4   2500  10313   -525   -574    256     36")
            XCTFail("Parsing a data point line as a station ID line should throw an error")
        } catch RucSounding.ParseError.lineTypeMismatch {
            return
        } catch {
            XCTFail("Parsing a data point line as a station ID line should throw a "
                    + "SoundingParseError.lineTypeMismatch")
        }
        
        let line = "      3           SAN                   12     kt"
        let stationInfoAndOther = try RucSounding.StationInfoAndOther(fromText: line)
        XCTAssertEqual(stationInfoAndOther.stationId, "SAN")
        XCTAssertEqual(stationInfoAndOther.radiosondeType, .sdc)
        XCTAssertEqual(stationInfoAndOther.windSpeedUnit, .kt)
        
        do {
            let _ = try RucSounding.StationInfoAndOther(fromText: "      4   2500  10313   -525   -574    256     36")
            XCTFail("Parsing a data point line as a station ID and others line should throw an error")
        } catch RucSounding.ParseError.lineTypeMismatch {
            return
        } catch {
            XCTFail("Parsing a data point line as a station ID and others line should throw a "
                    + " SoundingParseError.lineTypeMismatch")
        }
    }
    
    func testDataPointParsing() throws {
        let mandatoryLine = "      4   2500  10313   -525   -574    256     36"
        let mandatory = try RucSounding.LevelDataPoint(fromText: mandatoryLine)
        XCTAssertEqual(mandatory.type, .mandatoryLevel)
        XCTAssertEqual(mandatory.pressure, 250.0)
        XCTAssertEqual(mandatory.height, 10313)
        XCTAssertEqual(mandatory.temperature, -52.5)
        XCTAssertEqual(mandatory.dewPoint, -57.4)
        XCTAssertEqual(mandatory.windDirection, 256)
        XCTAssertEqual(mandatory.windSpeed, 36)
        
        let significantLine = "      5   2331  10762   -553   -602    235     36"
        let significant = try RucSounding.LevelDataPoint(fromText: significantLine)
        XCTAssertEqual(significant.type, .significantLevel)
        XCTAssertEqual(significant.pressure, 233.1)
        XCTAssertEqual(significant.height, 10762)
        XCTAssertEqual(significant.temperature, -55.3)
        XCTAssertEqual(significant.dewPoint, -60.2)
        XCTAssertEqual(significant.windDirection, 235)
        XCTAssertEqual(significant.windSpeed, 36)
        
        let mandatoryLineWithBlanks = "      4   8500  99999  99999  99999  99999  99999"
        let blanks = try RucSounding.LevelDataPoint(fromText: mandatoryLineWithBlanks)
        XCTAssertEqual(blanks.type, .mandatoryLevel)
        XCTAssertEqual(blanks.pressure, 850.0)
        XCTAssertNil(blanks.temperature)
        XCTAssertNil(blanks.dewPoint)
        XCTAssertNil(blanks.windDirection)
        XCTAssertNil(blanks.windSpeed)
        
        let windLine = "      6    262  24384  99999  99999     40     10   1235     88     90"
        let wind = try RucSounding.LevelDataPoint(fromText: windLine)
        XCTAssertEqual(wind.type, .windLevel)
        XCTAssertNil(wind.temperature)
        XCTAssertNil(wind.dewPoint)
        XCTAssertEqual(wind.windDirection, 40)
        XCTAssertEqual(wind.windSpeed, 10)
        
        let stationIdLine = "      1  23062  72290  32.78 117.06      9  99999"
        do {
            let _ = try RucSounding.LevelDataPoint(fromText: stationIdLine)
            XCTFail("Parsing a station ID line as a data point should throw an error")
        } catch RucSounding.ParseError.lineTypeMismatch {
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
        
        let sounding = try RucSounding(fromText: s)
        XCTAssertEqual(sounding.type, .op40)
        XCTAssertEqual(sounding.description, "Op40 analysis valid for grid point 6.9 nm / 66 deg from SAN:")
        XCTAssertEqual(sounding.data.dataPoints.count, 62)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 62)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 62)
        XCTAssertEqual(sounding.stationId, "SAN")
        XCTAssertEqual(sounding.data.cape, 0)
        XCTAssertEqual(sounding.data.cin, 0)
        
        let linesMinusGlobals = lines[0...1] + lines[3...]
        let minusGlobals = linesMinusGlobals.joined(separator: "\n")
        let _ = try RucSounding(fromText: minusGlobals)
        
        let linesMinusHeader = [lines[0]] + lines[2...]
        let missingHeader = linesMinusHeader.joined(separator: "\n")
        
        do {
            let _ = try RucSounding(fromText: missingHeader)
            XCTFail("Parsing a sounding with no header should throw an error")
        } catch RucSounding.ParseError.missingHeaders {
            return
        } catch {
            XCTFail("Parsing a sounding with no header should throw a SoundingParseError.missingHeaders, "
                    + "not a \(String(describing: error))")
        }
    }
    
    func testOutOfBoundsValueIgnoring() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "out-of-bounds-op40", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        let sounding = try RucSounding(fromText: s)

        sounding.data.dataPoints.filter({ $0.temperature != nil }).forEach {
            XCTAssertTrue(
                $0.temperature! >= -270.0 && $0.temperature! <= 100.0,
                "Temperature \($0.temperature!) is between absolute zero and boiling water temperature"
            )
        }
        
        sounding.data.dataPoints.filter({ $0.dewPoint != nil }).forEach {
            XCTAssertTrue(
                $0.dewPoint! >= -270.0 && $0.dewPoint! <= 100.0,
                "Dew point of \($0.dewPoint!) is between absolute zero and boiling water temperature"
            )
        }
    }
    
    func testRaobParsing() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "nkx-raob-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!

        let sounding = try RucSounding(fromText: s)
        XCTAssertEqual(sounding.type, .raob)
        XCTAssertEqual(sounding.description, "RAOB sounding valid at:")
        XCTAssertEqual(sounding.data.dataPoints.count, 231)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 89)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 162)
        XCTAssertEqual(sounding.stationId, "NKX")
    }
    
    func testNamParsing() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "iad-nam-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        
        let sounding = try RucSounding(fromText: s)
        XCTAssertEqual(sounding.type, .nam)
        XCTAssertEqual(sounding.description, "NAM analysis valid for grid point 8.8 nm / 330 deg from IAD:")
        XCTAssertEqual(sounding.stationId, "IAD")
        XCTAssertEqual(sounding.data.cape, 0)
        XCTAssertEqual(sounding.data.cin, 0)
        XCTAssertEqual(sounding.data.dataPoints.count, 39)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 39)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 39)
    }
    
    func testGfsParsing() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "ord-gfs-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        
        let sounding = try RucSounding(fromText: s)
        XCTAssertEqual(sounding.type, .gfs)
        XCTAssertEqual(sounding.description, "GFS analysis valid for grid point 4.6 nm / 285 deg from ORD:")
        XCTAssertEqual(sounding.stationId, "ORD")
        XCTAssertEqual(sounding.data.cape, 0)
        XCTAssertEqual(sounding.data.cin, 0)
        XCTAssertEqual(sounding.data.dataPoints.count, 31)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.temperature != nil && $0.dewPoint != nil }).count, 26)
        XCTAssertEqual(sounding.data.dataPoints.filter({ $0.windDirection != nil && $0.windSpeed != nil}).count, 31)
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
    
    func testSurfaceData() throws {
        let surfacePoint = RucSounding.LevelDataPoint(
            type: .surfaceLevel,
            pressure: 1000.0,
            height: nil,
            temperature: 15.0,
            dewPoint: 10.0,
            windDirection: nil,
            windSpeed: nil
        )
        
        let significantLevelJustAboveSurface = RucSounding.LevelDataPoint(
            type: .significantLevel,
            pressure: 900.0,
            height: nil,
            temperature: 14.0,
            dewPoint: 10.0,
            windDirection: nil,
            windSpeed: nil
        )
        
        let significantLevelUpHigh = RucSounding.LevelDataPoint(
            type: .significantLevel,
            pressure: 500.0,
            height: nil,
            temperature: -10.0,
            dewPoint: -20.0,
            windDirection: nil,
            windSpeed: nil
        )
        
        let withSurface = try RucSounding(withJustData: [surfacePoint, significantLevelJustAboveSurface, significantLevelUpHigh])
        let noSurface = try RucSounding(withJustData: [significantLevelJustAboveSurface, significantLevelUpHigh])
        
        XCTAssertEqual(withSurface.data.surfaceDataPoint, SoundingData.Point(fromRucDataPoint: surfacePoint), ".surfaceData returns surface data point")
        XCTAssertEqual(noSurface.data.surfaceDataPoint, SoundingData.Point(fromRucDataPoint: significantLevelJustAboveSurface),
                       ".surfaceData returns lowest available data if no surface data point exists")
    }
}
