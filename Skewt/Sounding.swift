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

enum SoundingParseError: Error {
    case empty
    case missingHeaders
    case unparseableLine(String)
    case lineTypeMismatch(String)
    case duplicateStationInfo
}

enum WindSpeedUnit: String {
    case ms = "ms"
    case kt = "kt"
}

enum DataPointType: Int {
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

enum RadiosondeType: Int {
    case vizA = 10
    case vizB = 11
    case sdc = 12
}

// Adding an init? that treats "99999" sentinel as nil when parsing values from String
fileprivate extension LosslessStringConvertible {
    /// Initialize a LosslessStringConvertible? (Int/Double/etc.) from String, returning nil
    /// if it is the sounding data unavailable value sentinel ("99999")
    init?(fromSoundingString s: String) {
        guard s != emptyValue else {
            return nil
        }
        
        self.init(s)
    }
}

/// Parsing columns of static width from sounding data
fileprivate extension String {
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
fileprivate extension String {
    func dateFromHeaderLine() throws -> Date {
        let columns = soundingColumns()
        let dateString = [columns[1], columns[2], columns[3], columns[4]]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")

        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "HH dd MMM yyyy"

        guard let date = dateFormatter.date(from: dateString) else {
            throw SoundingParseError.unparseableLine(self)
        }

        return date
    }
}

fileprivate extension Sequence where Element == String {
    /// Filters an Array of Strings based on a parseable sounding data type in the first column
    func filterByDataPointType(_ types: [DataPointType]) -> [Element] {
        return filter {
            guard let type = $0.soundingDataType() else {
                return false
            }

            return types.contains(type)
        }
    }
}

struct Sounding {
    let stationInfo: StationInfo
    let timestamp: Date
    let description: String
    
    let stationId: String
    let windSpeedUnit: WindSpeedUnit
    let type: RadiosondeType?
    
    let cape: Int?  // Convective Available Potential Energy in J/Kg
    let cin: Int?  // Convective Inhibition in J/Kg
    let helicity: Int?  // Storm-relative helicity in m^2/s^2
    let precipitableWater: Int?  // Precipitable water in model column in Kg/m^2
    
    let data: [LevelDataPoint]
}

/// Initializing a Sounding from text
extension Sounding {
    init(fromText text: String) throws {
        let lines = text.split(whereSeparator: \.isNewline).filter { !$0.isEmpty }.map { String($0) }
        
        guard lines.count >= 3 else {
            throw SoundingParseError.empty
        }
        
        description = lines[0]
        let headerLine = lines[1]
        let globalsLine = lines[2]
        let remainingLines = lines[3...]
        let stationIdLines = remainingLines.filterByDataPointType([.stationId])
        let stationIdAndOtherLines = remainingLines.filterByDataPointType([.stationIdAndOther])
        let dataLines = remainingLines.filterByDataPointType([.surfaceLevel, .significantLevel, .mandatoryLevel])
        
        guard stationIdLines.count == 1, stationIdAndOtherLines.count == 1 else {
            throw SoundingParseError.duplicateStationInfo
        }
        
        try timestamp = headerLine.dateFromHeaderLine()
        
        let globals = Sounding.globalsFromText(globalsLine)
        cape = globals["CAPE"]
        cin = globals["CIN"]
        helicity = globals["Helic"]
        precipitableWater = globals["PW"]
        
        stationInfo = try StationInfo(fromText: stationIdLines[0])
        
        let stationInfoAndOther = try StationInfoAndOther(fromText: stationIdAndOtherLines[0])
        stationId = stationInfoAndOther.stationId
        type = stationInfoAndOther.radiosondeType
        windSpeedUnit = stationInfoAndOther.windSpeedUnit
        
        data = try dataLines.map { try LevelDataPoint(fromText: $0) }
    }
    
    /// Dictionary of values from a line of key/value tuples
    ///
    /// e.g. "    CAPE      0    CIN      0  Helic  99999     PW  99999"
    /// produces ["CAPE": 0, "CIN": 0]
    static private func globalsFromText(_ s: String) -> [String: Int] {
        let columns = s.soundingColumns()
        var result: [String: Int] = [:]
        
        stride(from: 0, to: columns.count - 1, by: 2).forEach {
            let key = columns[$0]
            if let value = Int(fromSoundingString: columns[$0 + 1]) {
                result[key] = value
            }
        }
        
        return result
    }
}

struct StationInfo {
    let wbanId: Int
    let wmoId: Int
    let latitude: Double
    let longitude: Double
    let altitude: Double
}

extension StationInfo {
    init(fromText text: String) throws {
        let (type, columns) = try text.soundingTypeAndColumns()
        
        guard type == .stationId else {
            throw SoundingParseError.lineTypeMismatch(text)
        }
        
        guard let wbanId = Int(fromSoundingString: columns[0]),
              let wmoId = Int(fromSoundingString: columns[1]),
              let latitude = Double(fromSoundingString: columns[2]),
              let longitude = Double(fromSoundingString: columns[3]),
              let altitude = Double(fromSoundingString: columns[4]) else {
            throw SoundingParseError.unparseableLine(text)
        }
              
        self.wbanId = wbanId
        self.wmoId = wmoId
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
}

struct StationInfoAndOther {
    let stationId: String
    let radiosondeType: RadiosondeType?
    let windSpeedUnit: WindSpeedUnit
}

extension StationInfoAndOther {
    init(fromText text: String) throws {
        let (type, columns) = try text.soundingTypeAndColumns()

        guard type == .stationIdAndOther else {
            throw SoundingParseError.lineTypeMismatch(text)
        }
        
        stationId = columns[1].trimmingCharacters(in: .whitespaces)
        radiosondeType = RadiosondeType(rawValue: Int(columns[4]) ?? 0)
        
        guard let windSpeedUnit = WindSpeedUnit(rawValue: columns[5].trimmingCharacters(in: .whitespaces)) else {
            throw SoundingParseError.unparseableLine(text)
        }
        
        self.windSpeedUnit = windSpeedUnit
    }
}

struct LevelDataPoint {
    let type: DataPointType
    let pressure: Double
    let height: Int
    let temperature: Double
    let dewPoint: Double
    let windDirection: Int
    let windSpeed: Int
}

extension LevelDataPoint {
    static let types: [DataPointType] = [.mandatoryLevel, .significantLevel, .surfaceLevel]
    
    init(fromText text: String) throws {
        let (type, columns) = try text.soundingTypeAndColumns()
        
        guard LevelDataPoint.types.contains(type) else {
            throw SoundingParseError.lineTypeMismatch(text)
        }
        
        guard let pressure = Double(fromSoundingString: columns[0]),
              let height = Int(fromSoundingString: columns[1]),
              let temperature = Double(fromSoundingString: columns[2]),
              let dewPoint = Double(fromSoundingString: columns[3]),
              let windDirection = Int(fromSoundingString: columns[4]),
              let windSpeed = Int(fromSoundingString: columns[5]) else {
            throw SoundingParseError.unparseableLine(text)
        }
            
        self.type = type
        self.pressure = pressure
        self.height = height
        self.temperature = temperature
        self.dewPoint = dewPoint
        self.windDirection = windDirection
        self.windSpeed = windSpeed
    }
}
