//
//  NCAFSoundingList.swift
//  Skewt
//
//  Created by Jason Neel on 2/8/26.
//

import Foundation

/// A collection of the latest sounding data for all locations served by
/// https://weather.rap.ucar.edu/data/upper/Current.rawins
struct NCAFSoundingList {
    let dataByStationId: [Int: NCAFSounding]
}

struct NCAFSounding: Sounding {
    var data: SoundingData
}

private struct PartialSounding {
    var time: Date
    var stationId: Int

    var mandatory: [SoundingData.Point] = []
    var significantTemp: [SoundingData.Point] = []
    var significantWind: [SoundingData.Point] = []

    var surface: SoundingData.Point?
}

typealias SoundingKey = String // "\(stationId)-\(time)"

extension NCAFSoundingList {
    enum ParsingError: Error {
        case unrecognizedFormat
    }
    
    init(fromString s: String) throws {
        let tokens = s
            .replacingOccurrences(of: "\u{01}", with: "")
            .replacingOccurrences(of: "\u{03}", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var index = 0
        var soundings: [SoundingKey: PartialSounding] = [:]

        func key(_ station: Int, _ time: Date) -> SoundingKey {
            "\(station)-\(time.timeIntervalSince1970)"
        }

        while index < tokens.count {
            let token = tokens[index]

            guard token == "TTAA" || token == "TTBB" else {
                index += 1
                continue
            }

            guard index + 2 < tokens.count else {
                break
            }

            let type = token
            let timeToken = tokens[index + 1]
            let stationToken = tokens[index + 2]

            guard let stationId = Int(stationToken) else {
                index += 1
                continue
            }

            let time = Self.parseTTAATime(timeToken)
            let k = key(stationId, time)

            if soundings[k] == nil {
                soundings[k] = PartialSounding(time: time, stationId: stationId)
            }

            index += 3

            switch type {
            case "TTAA":
                try NCAFSoundingList.parseTTAA(tokens, &index, &soundings[k]!)
            case "TTBB":
                try NCAFSoundingList.parseTTBB(tokens, &index, &soundings[k]!)
            default:
                break
            }
        }

        var final: [Int: NCAFSounding] = [:]

        for (_, ps) in soundings {
            let data = SoundingData(
                time: ps.time,
                elevation: ps.surface?.height.map(Int.init) ?? 0,
                dataPoints: (ps.mandatory + ps.significantTemp + ps.significantWind)
                    .sorted { $0.pressure > $1.pressure },
                surfaceDataPoint: ps.surface,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )

            final[ps.stationId] = NCAFSounding(data: data)
        }

        self.dataByStationId = final
    }
    
    private static func parseTTAATime(_ s: String) -> Date {
        let s = s.trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let rawDay = Int(s.prefix(2)) ?? 1
        let hour = Int(s.dropFirst(2).prefix(2)) ?? 0

        // TTAA rule: if day >= 50, subtract 50 (winds in knots)
        let day = rawDay >= 50 ? rawDay - 50 : rawDay

        let calendar = Calendar(identifier: .gregorian)
        let tz = TimeZone(secondsFromGMT: 0)!
        let now = Date()

        var components = calendar.dateComponents(in: tz, from: now)
        components.timeZone = tz
        components.day = day
        components.hour = hour
        components.minute = 0
        components.second = 0

        // Handle month rollover (e.g. sounding from last month on the 1st)
        if let candidate = calendar.date(from: components),
           candidate > now,
           let month = components.month {
            components.month = month - 1
        }

        return calendar.date(from: components) ?? now
    }
    
    static func temperatureAndDewPoint(fromString s: String) throws -> (Double?, Double?) {
        let s = s.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        guard s != "/////" else {
            return (nil, nil)
        }
        
        guard s.count == 5,
              let rawTemperature = Int(s.prefix(3)) else {
            throw ParsingError.unrecognizedFormat
        }
        
        let sign = (rawTemperature % 2) == 0 ? 1 : -1
        let temperature = Double(rawTemperature * sign) * 0.1
        let dewPoint: Double?
        
        if let dpd = try NCAFSoundingList.dewPointDepression(fromString: String(s.suffix(2))) {
            dewPoint = temperature - dpd
        } else {
            dewPoint = nil
        }
        
        return (temperature, dewPoint)
    }
    
    private static func dewPointDepression(fromString s: String) throws -> Double? {
        let dd = s.suffix(2)
        
        guard dd != "//" else {
            return nil
        }
        
        guard let intValue = Int(dd) else {
            throw ParsingError.unrecognizedFormat
        }
        
        if intValue <= 50 {
            return Double(intValue) * 0.1
        } else {
            return Double(intValue - 50)
        }
    }
    
    private static func parseTTAA(
        _ tokens: [String],
        _ index: inout Int,
        _ ps: inout PartialSounding
    ) throws {
        while index < tokens.count {
            let g = tokens[index]
            let triplet = "\(index)-\(index+2): \(tokens[index]) \(index + 1 < tokens.count ? tokens[index+1] : "") \(index + 2 < tokens.count ? tokens[index+2] : "")"

            if g == "TTAA" || g == "TTBB" || g == "PPBB" {
                break
            }

            if g == "31313" || g == "51515" {
                index += 1
                continue
            }

            guard isPressureGroup(g),
                  index + 1 < tokens.count else {
                index += 1
                continue
            }

            let pGroup = g
            let tGroup: String?
            var isTerminating = g.suffix(1) == "="
            index += 1
            
            if !isTerminating {
                tGroup = tokens[index]
                
                if tGroup!.rangeOfCharacter(from: .uppercaseLetters) != nil {
                    break
                }
                
                isTerminating = tGroup!.suffix(1) == "="
                index += 1
            } else {
                tGroup = nil
            }

            var wGroup: String?
            if !isTerminating, index < tokens.count, isWindGroup(tokens[index]) {
                wGroup = tokens[index]
                index += 1
            }

            let (p, h) = decodePressureHeight(pGroup)
            let (t, d): (Double?, Double?)
            
            if let tGroup = tGroup {
                (t, d) = try NCAFSoundingList.temperatureAndDewPoint(fromString: tGroup)
            } else {
                (t, d) = (nil, nil)
            }
            
            let (wd, ws): (Int?, Double?)
            
            if let wGroup = wGroup {
                (wd, ws) = try NCAFSoundingList.windSpeedAndDirection(fromString: wGroup)
            } else {
                (wd, ws) = (nil, nil)
            }
            
            let point = SoundingData.Point(
                pressure: p,
                height: h,
                temperature: t,
                dewPoint: d,
                windDirection: wd,
                windSpeed: ws
            )
            
            ps.mandatory.append(point)
            
            if isTTAASurfacePressureGroup(g) {
                ps.surface = point
            }
        }
    }
    
    private static func parseTTBB(
        _ tokens: [String],
        _ index: inout Int,
        _ ps: inout PartialSounding
    ) throws {
        while index + 1 < tokens.count {
            let pGroup = tokens[index]
            
            if pGroup.suffix(1) == "=" || !isTTBBPressureGroup(pGroup) {
                break
            }
            
            let tGroup = tokens[index + 1]
            index += 2

            let pressure = try NCAFSoundingList.decodeTTBBPressure(pGroup)
            let (t, d) = try NCAFSoundingList.temperatureAndDewPoint(fromString: tGroup)

            let point = SoundingData.Point(
                pressure: pressure,
                height: nil,
                temperature: t,
                dewPoint: d,
                windDirection: nil,
                windSpeed: nil
            )

            ps.significantTemp.append(point)
            
            if NCAFSoundingList.isTTBBSurfacePressureGroup(pGroup) && ps.surface == nil {
                ps.surface = point
            }
        }
    }
    
    private static func isTTBBPressureGroup(_ g: String) -> Bool {
        let g = g.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        guard g.count == 5 else {
            return false
        }
        
        let prefix = g.prefix(2)
        
        return prefix.prefix(1) == prefix.suffix(1)
    }
    
    private static func decodeTTBBPressure(_ g: String) throws -> Double {
        let g = g.trimmingCharacters(in: CharacterSet(charactersIn: "="))
        
        guard g.count == 5, let value = Int(g.suffix(3)) else {
            throw ParsingError.unrecognizedFormat
        }
        
        let prefix = g.prefix(2)
        
        if prefix == "00" {
            return Double(1_000 + value)
        } else {
            return Double(value)
        }
    }
    
    private static func isWindGroup(_ g: String) -> Bool {
        let g = g.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        return g.count == 5
    }
    
    private static func isTTAASurfacePressureGroup(_ g: String) -> Bool {
        let g = g.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        return g.count == 5 && g.prefix(2) == "99"
    }
    
    private static func isTTBBSurfacePressureGroup(_ g: String) -> Bool {
        let g = g.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        return g.count == 5 && g.prefix(2) == "00"
    }
    
    private static func isPressureGroup(_ g: String) -> Bool {
        let g = g.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        guard g.count == 5 else {
            return false
        }
        
        return ["99","92","85","70","50","40","30","20","10"]
            .contains(g.prefix(2))
    }
    
    private static func decodePressureHeight(_ g: String) -> (Double, Double?) {
        let g = g.trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let prefix = g.prefix(2)
        let rest = Int(g.suffix(3)) ?? 0

        // TODO: Handle negative geopotential height
        
        switch prefix {
        case "99": // surface
            return (Double(1000 + rest), nil)
        case "92": return (925, Double(rest))
        case "85": return (850, Double(rest))
        case "70": return (700, Double(rest))
        case "50": return (500, Double(rest))
        case "40": return (400, Double(rest))
        case "30": return (300, Double(rest))
        case "20": return (200, Double(rest))
        case "10": return (100, Double(rest))
        default:
            return (Double(rest), nil)
        }
    }
    
    static func windSpeedAndDirection(fromString s: String) throws -> (Int?, Double?) {
        let s = s.trimmingCharacters(in: CharacterSet(charactersIn: "="))

        guard s != "/////" else {
            return (nil, nil)
        }
        
        guard s.count == 5, let rawDirection = Int(s.prefix(3)), let rawSpeed = Int(s.suffix(2)) else {
            throw ParsingError.unrecognizedFormat
        }
        
        let extraHundreds = rawDirection % 5
        let direction = rawDirection - extraHundreds
        let speed = rawSpeed + (extraHundreds * 100)
        
        return (direction, Double(speed))
    }
}
