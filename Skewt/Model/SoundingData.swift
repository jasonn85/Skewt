//
//  SoundingData.swift
//  Skewt
//
//  Created by Jason Neel on 10/26/24.
//

import Foundation

struct SoundingData: Codable {
    struct Point: Codable, Hashable {
        let pressure: Double
        let height: Double?
        let temperature: Double?
        let dewPoint: Double?
        let windDirection: Int?
        let windSpeed: Double?
    }
    
    let time: Date
    let elevation: Int
    let dataPoints: [Point]
    let surfaceDataPoint: Point?
    
    let cape: Int?  // Convective Available Potential Energy in J/Kg
    let cin: Int?  // Convective Inhibition in J/Kg
    let helicity: Int?  // Storm-relative helicity in m^2/s^2
    let precipitableWater: Int?  // Precipitable water in model column in Kg/m^2
}

// Value interpolation
extension SoundingData {
    /// Find the nearest double value to a key value via linear interpolation
    func interpolatedValue(
        for valuePath: KeyPath<Point, Double?>,
        atPressure pressure: Double
    ) -> Double? {
        let points = dataPoints.filter { $0[keyPath: valuePath] != nil }
        
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
    
    func closestValue(toPressure pressure: Double, withValueFor valuePath: KeyPath<Point, Double?>) -> Point? {
        let points = dataPoints.filter { $0[keyPath: valuePath] != nil }
        
        guard points.count > 0 else {
            return nil
        }
        
        return points.reduce(points[0]) { abs($1.pressure - pressure) < abs($0.pressure - pressure) ? $1 : $0 }
    }
}

extension SoundingData.Point {
    var altitudeInFeet: Double {
        let altitudeInM = height ?? Pressure.standardAltitude(forPressure: pressure)
        
        return Double(altitudeInM) * 3.28084
    }
}
