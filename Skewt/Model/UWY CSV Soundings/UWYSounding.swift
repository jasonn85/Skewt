//
//  UWYSounding.swift
//  Skewt
//
//  Created by Jason Neel on 2/16/26.
//

import Foundation

struct UWYSounding {
    let data: SoundingData
}

extension UWYSounding {
    init?(fromCsvString s: String) {
        let lines = s
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        guard lines.count > 1,
              let header = lines.first else {
            return nil
        }
        
        let columnNames = header.components(separatedBy: ",")
        let rows = lines[1...].map { $0.components(separatedBy: ",") }
        
        guard rows.allSatisfy({ $0.count >= columnNames.count }) else {
            return nil
        }
        
        let data = rows
            .compactMap {
                let d = Dictionary(uniqueKeysWithValues: zip(columnNames, $0))
                
                return SoundingData.Point(fromUwyCsvDictionary: d)
            }
        
        guard let surface = data.first,
                let time = surface.time else {
            return nil
        }
        
        self.data = SoundingData(
            time: time,
            dataPoints: data,
            surfaceDataPoint: surface,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )
    }
}

fileprivate extension SoundingData.Point {
    private static let uwyDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .gmt
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        return dateFormatter
    }()
    
    init?(fromUwyCsvDictionary d: Dictionary<String, String>) {
        guard let timeString = d["time"],
              let time = SoundingData.Point.uwyDateFormatter.date(from: timeString),
              let pressure = d.doubleValue(forKey: "pressure_hPa") else {
            return nil
        }
        
        let windSpeedKnots: Double?
        
        if let windSpeedMs = d.doubleValue(forKey: "wind speed_m/s") {
            windSpeedKnots = windSpeedMs * 1.94384
        } else {
            windSpeedKnots = nil
        }
        
        self = SoundingData.Point(
            time: time,
            latitude: d.doubleValue(forKey: "latitude"),
            longitude: d.doubleValue(forKey: "longitude"),
            pressure: pressure,
            height: d.doubleValue(forKey: "geopotential height_m"),
            temperature: d.doubleValue(forKey: "temperature_C"),
            dewPoint: d.doubleValue(forKey: "dew point temperature_C"),
            windDirection: d.intValue(forKey: "wind direction_degree"),
            windSpeed: windSpeedKnots
        )
    }
}

fileprivate extension Dictionary where Key == String, Value == String {
    func doubleValue(forKey key: String) -> Double? {
        guard let string = self[key]?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        
        return Double(string)
    }
    
    func intValue(forKey key: String) -> Int? {
        guard let string = self[key]?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        
        return Int(string)
    }
}
