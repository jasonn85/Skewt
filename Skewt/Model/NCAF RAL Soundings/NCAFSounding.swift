//
//  NCAFSounding.swift
//  Skewt
//
//  Created by Jason Neel on 2/9/26.
//

import Foundation

struct NCAFSounding {
    let header: Header
    let messages: [NCAFSoundingMessage]
    
    /// Header per https://www.weather.gov/tg/headef
    struct Header {
        let dataType: DataType
        let originatingStation: String
        let timestamp: DateComponents
        let issuanceType: IssuanceType?
        
        /// Issuance type per https://www.weather.gov/tg/bbb
        enum IssuanceType {
            case delayed(String)  // A-X index, Y for lost record, Z over 24 hours old
            case correction(String)  // A-X index, Y for lost record, Z over 24 hours old
            case amendment(String)  // A-X index, Y for lost record, Z over 24 hours old
            case segment(String)  // AA through YZ and ZA through ZZ
        }
        
        enum DataType {
            case upperAirData(UpperAirDataType)
            case other
        }
        
        enum UpperAirDataType: String {
            case aircraftReportsCodarOrAirep = "A"
            case aircraftReportsAmdar = "D"
            case upperLevelPressureTempHumidityWindPartD = "E"
            case upperLevelPressureTempHumidityWindPartsCD = "F"
            case upperWindPartB = "G"
            case upperWindPartC = "H"
            case upperWindPartsAB = "I"
            case upperLevelPressureTempHumidityWindPartB = "K"
            case upperLevelPressureTempHumidityWindPartC = "L"
            case upperLevelPressureTempHumidityWindPartsAB = "M"
            case rocketsonde = "N"
            case upperWindPartA = "P"
            case upperWindPartD = "Q"
            case aircraftReportRecco = "R"
            case upperLevelPressureTempHumidityWindPartA = "S"
            case aircraftReportCodar = "T"
            case misc = "X"
            case upperWindPartsCD = "Y"
            case upperLevelPressureTempHumidityWindAerialSonde = "Z"
        }
    }
}

extension NCAFSounding {
    init?(fromString s: String) {
        let lines = s
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        guard lines.count >= 3,
            let header = Header(fromString: lines[1]) else {
                return nil
        }
        
        self.header = header

        let messages = lines
            .dropFirst(2)
            .joined(separator: " ")
            .components(separatedBy: "=")
            .filter { !$0.isEmpty }
            .compactMap(NCAFSoundingMessage.init(fromString:))
        
        self.messages = messages
    }
}

extension NCAFSounding.Header {
    init?(fromString s: String) {
        let groups = s.components(separatedBy: .whitespaces)
        
        guard (3...4).contains(groups.count),
              let dataType = DataType(fromString: String(groups[0].prefix(2))),
              let timestamp = NCAFSounding.Header.dateComponents(fromString: groups[2]) else {
            return nil
        }
        
        self.dataType = dataType
        self.originatingStation = groups[1]
        self.timestamp = timestamp
        
        if groups.count == 5 {
            self.issuanceType = NCAFSounding.Header.IssuanceType(fromString: groups[3])
        } else {
            self.issuanceType = nil
        }
    }
    
    static func dateComponents(fromString s: String) -> DateComponents? {
        guard s.count == 6,
                let day = Int(s.prefix(2)),
                let hour = Int(s.dropFirst(2).prefix(2)),
                let minute = Int(s.suffix(2)) else {
            return nil
        }
        
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .gmt
        components.day = day
        components.hour = hour
        components.minute = minute
        
        return components
    }
}

extension NCAFSounding.Header.IssuanceType {
    init?(fromString s: String) {
        guard s.count == 3 else {
            return nil
        }
        
        let prefix = s.prefix(2)
        
        switch prefix {
        case "RR":
            self = .delayed(String(s.suffix(1)))
        case "CC":
            self = .correction(String(s.suffix(1)))
        case "AA":
            self = .amendment(String(s.suffix(1)))
        case let p where p.hasPrefix("P"):
            self = .segment(String(s.suffix(2)))
        default:
            return nil
        }
    }
}

extension NCAFSounding.Header.DataType {
    init?(fromString s: String) {
        guard s.count == 2 else {
            return nil
        }
        
        if s.prefix(1) == "U" {
            guard let upperAirType = NCAFSounding.Header.UpperAirDataType(rawValue: String(s.suffix(1))) else {
                return nil
            }
            
            self = .upperAirData(upperAirType)
        } else {
            self = .other
        }
    }
}
