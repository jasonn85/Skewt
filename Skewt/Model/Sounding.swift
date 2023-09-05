//
//  Sounding.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//  per https://rucsoundings.noaa.gov/raob_format.html
//

import Foundation

fileprivate let columnWidth = 7
fileprivate let emptyValue = "99999"  // Unavailable value sentinel per RAOB format

/// A rawindsonde sounding
struct Sounding: Codable {
    let stationInfo: StationInfo
    let type: SoundingType
    let timestamp: Date
    let description: String
    
    let stationId: String
    let windSpeedUnit: WindSpeedUnit
    let radiosondeCode: RadiosondeCode?
    
    let cape: Int?  // Convective Available Potential Energy in J/Kg
    let cin: Int?  // Convective Inhibition in J/Kg
    let helicity: Int?  // Storm-relative helicity in m^2/s^2
    let precipitableWater: Int?  // Precipitable water in model column in Kg/m^2
    
    let data: [LevelDataPoint]
}

struct StationInfo: Codable {
    let wbanId: Int?
    let wmoId: Int?
    let latitude: Double
    let longitude: Double
    let altitude: Int?
}

enum SoundingType: String, Codable, CaseIterable {
    case op40 = "Op40"
    case bak40 = "Bak40"
    case nam = "NAM"
    case gfs = "GFS"
    case raob = "RAOB"
}

struct LevelDataPoint: Codable, Hashable {
    let type: DataPointType
    let pressure: Double
    let height: Int?
    let temperature: Double?
    let dewPoint: Double?
    let windDirection: Int?
    let windSpeed: Int?
}

enum SoundingParseError: Error, Codable {
    case empty
    case missingHeaders
    case unparseableLine(String)
    case lineTypeMismatch(String)
    case duplicateStationInfo
}

enum WindSpeedUnit: String, Codable {
    case ms = "ms"
    case kt = "kt"
}

enum DataPointType: Int, Codable {
    case stationId = 1
    case soundingChecks = 2
    case stationIdAndOther = 3
    case mandatoryLevel = 4
    case significantLevel = 5
    case windLevel = 6
    case tropopauseLevel = 7
    case maximumWindLevel = 8
    case surfaceLevel = 9
}

struct StationInfoAndOther: Codable {
    let stationId: String
    let radiosondeType: RadiosondeCode?
    let windSpeedUnit: WindSpeedUnit
}

enum RadiosondeCode: Int, Codable {
    case vizA = 10
    case vizB = 11
    case sdc = 12
}

// Adding an init? that treats "99999" sentinel as nil when parsing values from String
internal extension LosslessStringConvertible {
    /// Initialize a LosslessStringConvertible? (Int/Double/etc.) from String, returning nil
    /// if it is the sounding data unavailable value sentinel ("99999")
    init?(fromSoundingString s: any StringProtocol) {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        
        guard trimmed != emptyValue else {
            return nil
        }
        
        self.init(trimmed)
    }
}

internal extension Int {
    func doubleFromTenths() -> Double { Double(self) / 10.0 }
}

/// Parsing columns of static width from sounding data
internal extension String {
    /// Returns column slices of a fixed width, including whitespace characters
    private func slices(ofLength l: Int) -> [Substring] {
        var i = self.startIndex
        var slices: [Substring] = []
        
        while i < endIndex {
            let end = self.index(i, offsetBy: l, limitedBy: endIndex) ?? endIndex
            slices.append(self[i..<end])
            i = end
        }
        
        return slices
    }
    
    /// Splits the String into one String for each sounding data column (fixed width of 7)
    func soundingColumns() -> [String] {
        return slices(ofLength: columnWidth).map { String($0) }
    }
    
    func soundingDataType() -> DataPointType? {
        guard let firstColumn = soundingColumns().first,
              let typeInt = Int(fromSoundingString: firstColumn),
              let type = DataPointType(rawValue: typeInt) else {
            return nil
        }
        
        return type
    }
    
    /// Returns a tuple of the data point type and all following columns of [String] data.
    /// Throws SoundingParseError.unparseableLine if unparseable or containing an unrecognized type.
    func soundingTypeAndColumns() throws -> (DataPointType, [String])  {
        let columns = soundingColumns()
        
        guard let typeInt = Int(fromSoundingString: columns[0]),
              let type = DataPointType(rawValue: typeInt) else {
            throw SoundingParseError.unparseableLine(self)
        }
        
        return (type, Array(columns[1...]))
    }
}

/// Parsing date (date and hour) from the type/time line of sounding data
/// e.g. "Op40        22     15      Feb    2023"
internal extension String {
    func dateFromHeaderLine() throws -> Date {
        // Discard the first column and join the others with single spaces
        // Note that the column spacing in this line is infuriatingly different than all the other lines
        //  in sounding data.
        let components = components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let dateString = components[1...].joined(separator: " ")
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)!
        dateFormatter.dateFormat = "HH dd MMM yyyy"

        guard let date = dateFormatter.date(from: dateString) else {
            throw SoundingParseError.unparseableLine(self)
        }

        return date
    }
}

// Parsing key/value tuples from sounding data
internal extension String {
    /// Dictionary of values from a line of key/value tuples
    ///
    /// e.g. "    CAPE     10    CIN      0  Helic  99999     PW  99999"
    /// produces ["CAPE": 10, "CIN": 0]
    func globals() -> [String: Int] {
        let columns = soundingColumns()
        var result: [String: Int] = [:]
        
        stride(from: 0, to: columns.count - 1, by: 2).forEach {
            let key = columns[$0].trimmingCharacters(in: .whitespaces)
            if let value = Int(fromSoundingString: columns[$0 + 1]) {
                result[key] = value
            }
        }
        
        return result
    }
}

internal extension Collection where Element == String {
    /// Filters an Array of Strings based on a parseable sounding data type in the first column
    func filter(byDataTypes types: [DataPointType]) -> [Element] {
        filter {
            guard let type = $0.soundingDataType() else {
                return false
            }

            return types.contains(type)
        }
    }
    
    func firstIndexContainingData() -> Self.Index? {
        firstIndex(where: { $0.soundingDataType() != nil })
    }
}

/// Initializing a Sounding from multiline text
extension Sounding {
    init(fromText text: String) throws {
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.isEmpty }.map { String($0) }
        
        guard let firstDataIndex = lines.firstIndexContainingData() else {
            throw SoundingParseError.empty
        }
        
        description = lines[0]
        let headerLine = lines[1]
        let dataLines = lines[firstDataIndex...]
        let stationIdLines = dataLines.filter(byDataTypes:[.stationId])
        let stationIdAndOtherLines = dataLines.filter(byDataTypes:[.stationIdAndOther])
        let soundingDataLines = dataLines.filter(byDataTypes:LevelDataPoint.types)
        
        guard let typeString = headerLine.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces).first,
              let type = SoundingType(rawValue: typeString) else {
            throw SoundingParseError.missingHeaders
        }
        
        guard stationIdLines.count == 1, stationIdAndOtherLines.count == 1 else {
            throw SoundingParseError.duplicateStationInfo
        }
        
        self.type = type
        try timestamp = headerLine.dateFromHeaderLine()
        
        if firstDataIndex > 2 {
            let globals = lines[2].globals()
            cape = globals["CAPE"]
            cin = globals["CIN"]
            helicity = globals["Helic"]
            precipitableWater = globals["PW"]
        } else {
            cape = nil
            cin = nil
            helicity = nil
            precipitableWater = nil
        }
        
        stationInfo = try StationInfo(fromText: stationIdLines[0])
        
        let stationInfoAndOther = try StationInfoAndOther(fromText: stationIdAndOtherLines[0])
        stationId = stationInfoAndOther.stationId
        radiosondeCode = stationInfoAndOther.radiosondeType
        windSpeedUnit = stationInfoAndOther.windSpeedUnit
        
        data = try soundingDataLines.map { try LevelDataPoint(fromText: $0) }
    }
}

// Initializing StationInfo from a line of text
extension StationInfo {
    init(fromText text: String) throws {
        // Use regex for StationInfo parsing because the station info line breaks the format of fixed
        // width columns for N/S/E/W suffixes on latitude/longitude; that suffix spills into the next
        // column. Regex for this one case felt better than rewriting the column parsing to handle this.
        let pattern = /\s*1\s+(\d+)\s+(\d+)\s+([\d.]+)([NS]?)\s*([\d.]+)([EW]?)\s+(\d+)\s+(\d+).*/
        
        guard let result = try? pattern.wholeMatch(in: text),
              var latitude = Double(fromSoundingString: result.3),
              var longitude = Double(fromSoundingString: result.5) else {
            if let lineType = text.soundingDataType(), lineType != .stationId {
                throw SoundingParseError.lineTypeMismatch(text)
            }
            
            throw SoundingParseError.unparseableLine(text)
        }
        
        let wbanId = Int(fromSoundingString: result.1)
        let wmoId = Int(fromSoundingString: result.2)
        let altitude = Int(fromSoundingString: result.7)
        
        // Only assume southern hemisphere (negative latitude) if an S is present
        if result.4 == "S" {
            latitude = -latitude
        }
        
        // Only assume eastern hemisphere (positive longitude) if a "E" is present
        if result.6 != "E" {
            longitude = -longitude
        }

        self.wbanId = wbanId
        self.wmoId = wmoId
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
}

// Initializing StationInfoAndOther from a line of text
extension StationInfoAndOther {
    init(fromText text: String) throws {
        let (type, columns) = try text.soundingTypeAndColumns()

        guard type == .stationIdAndOther else {
            throw SoundingParseError.lineTypeMismatch(text)
        }
        
        stationId = columns[1].trimmingCharacters(in: .whitespaces)
        radiosondeType = RadiosondeCode(rawValue: Int(columns[4]) ?? 0)
        
        guard let windSpeedUnit = WindSpeedUnit(rawValue: columns[5].trimmingCharacters(in: .whitespaces)) else {
            throw SoundingParseError.unparseableLine(text)
        }
        
        self.windSpeedUnit = windSpeedUnit
    }
}

// Initializing a data point from a line of text
extension LevelDataPoint {
    // Row types that contain sounding data that can be parsed as a LevelDataPoint
    static let types: [DataPointType] = [.surfaceLevel, .significantLevel,
                                         .mandatoryLevel, .windLevel,
                                         .maximumWindLevel]
    
    init(fromText text: String) throws {
        let (type, columns) = try text.soundingTypeAndColumns()
        
        guard LevelDataPoint.types.contains(type) else {
            throw SoundingParseError.lineTypeMismatch(text)
        }
        
        guard let pressure = Int(fromSoundingString: columns[0]) else {
            throw SoundingParseError.unparseableLine(text)
        }
            
        self.type = type
        self.pressure = pressure.doubleFromTenths()
        self.height = Int(fromSoundingString: columns[1])
        self.temperature = Int(fromSoundingString: columns[2])?.doubleFromTenths()
        self.dewPoint = Int(fromSoundingString: columns[3])?.doubleFromTenths()
        self.windDirection = Int(fromSoundingString: columns[4])
        self.windSpeed = Int(fromSoundingString: columns[5])
    }
}

// Value interpolation
extension Sounding {
    /// Find the nearest double value to a key value via linear interpolation
    func nearestValueToPressure(
        _ pressure: Double,
        valuePath: KeyPath<LevelDataPoint, Double?>
    ) -> Double? {
        let points = data
            .filter { $0[keyPath: valuePath] != nil }
        
        guard points.count > 0 else {
            return nil
        }
        
        if let exactMatch = points.first(where: { $0.pressure == pressure }) {
            return exactMatch[keyPath: valuePath]
        }
        
        let below = points.filter { $0.pressure > pressure }
        let above = points.filter { $0.pressure < pressure }
        
        guard below.count > 0 else {
            return above.first![keyPath: valuePath]
        }
        
        guard above.count > 0 else {
            return below.last![keyPath: valuePath]
        }
        
        return (below.last![keyPath: valuePath]! + above.first![keyPath: valuePath]!) / 2.0
    }
}
