//
//  SoundingData.swift
//  Skewt
//
//  Created by Jason Neel on 10/26/24.
//

import Foundation

struct SoundingData: Codable, Equatable, Sendable {
    struct Point: Codable, Hashable {
        let time: Date?
        let latitude: Double?
        let longitude: Double?
        let pressure: Double  // Pressure in millibars
        let height: Double?  // Geopotential height in meters
        let temperature: Double?  // Temperature in C
        let dewPoint: Double?  // Dew point in C
        let windDirection: Int?  // Wind direction in true heading
        let windSpeed: Double?  // Wind speed in knots
    }
    
    let time: Date
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
        
        let lowerPressurePoint = points
            .filter { $0.pressure > pressure }
            .min { $0.pressure < $1.pressure }
        let upperPressurePoint = points
            .filter { $0.pressure < pressure }
            .max { $0.pressure < $1.pressure }
        
        guard let lowerPressurePoint else {
            return points.min { $0.pressure < $1.pressure }?[keyPath: valuePath]
        }
        
        guard let upperPressurePoint else {
            return points.max { $0.pressure < $1.pressure }?[keyPath: valuePath]
        }
        
        guard let lowerValue = lowerPressurePoint[keyPath: valuePath],
              let upperValue = upperPressurePoint[keyPath: valuePath] else {
            return nil
        }
        
        let fraction = (pressure - lowerPressurePoint.pressure)
            / (upperPressurePoint.pressure - lowerPressurePoint.pressure)
        return lowerValue + fraction * (upperValue - lowerValue)
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
