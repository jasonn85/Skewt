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
        let separators = CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "="))
        let tokens = s
            .components(separatedBy: separators)
            .filter { !$0.isEmpty && $0 != "=" }

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
    
    static func temperatureAndDewPoint(fromString s: String) throws -> (Double, Double) {
        guard s.count == 5,
              let rawTemperature = Int(s.prefix(3)),
              let rawDewPointDepression = Int(s.suffix(2)) else {
            throw ParsingError.unrecognizedFormat
        }
        
        let sign = (rawTemperature % 2) == 0 ? 1 : -1
        let temperature = Double(rawTemperature * sign) * 0.1
        let dewPointDepression: Double
        
        if rawDewPointDepression <= 50 {
            dewPointDepression = Double(rawDewPointDepression) * 0.1
        } else {
            dewPointDepression = Double(rawDewPointDepression - 50)
        }
        
        return (temperature, temperature - dewPointDepression)
    }
    
    private static func parseTTAA(
        _ tokens: [String],
        _ index: inout Int,
        _ ps: inout PartialSounding
    ) throws {
        while index < tokens.count {
            let g = tokens[index]

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
            let tGroup = tokens[index + 1]
            index += 2

            var wGroup: String?
            if index < tokens.count, isWindGroup(tokens[index]) {
                wGroup = tokens[index]
                index += 1
            }

            let (p, h) = decodePressureHeight(pGroup)
            let (t, d) = try NCAFSoundingList.temperatureAndDewPoint(fromString: tGroup)
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
            
            if !isTTBBPressureGroup(pGroup) {
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
        guard g.count == 5 else {
            return false
        }
        
        let prefix = g.prefix(2)
        
        return prefix.prefix(1) == prefix.suffix(1)
    }
    
    private static func decodeTTBBPressure(_ g: String) throws -> Double {
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
        g.count == 5
    }
    
    private static func isTTAASurfacePressureGroup(_ g: String) -> Bool {
        g.count == 5 && g.prefix(2) == "99"
    }
    
    private static func isTTBBSurfacePressureGroup(_ g: String) -> Bool {
        g.count == 5 && g.prefix(2) == "00"
    }
    
    private static func isPressureGroup(_ g: String) -> Bool {
        guard g.count == 5 else {
            return false
        }
        
        return ["99","92","85","70","50","40","30","20","10"]
            .contains(g.prefix(2))
    }
    
    private static func decodePressureHeight(_ g: String) -> (Double, Double?) {
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
    
    static func windSpeedAndDirection(fromString s: String) throws -> (Int, Double) {
        guard s.count == 5, let rawDirection = Int(s.prefix(3)), let rawSpeed = Int(s.suffix(2)) else {
            throw NCAFSoundingList.ParsingError.unrecognizedFormat
        }
        
        let extraHundreds = rawDirection % 5
        let direction = rawDirection - extraHundreds
        let speed = rawSpeed + (extraHundreds * 100)
        
        return (direction, Double(speed))
    }
}
