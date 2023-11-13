//
//  SoundingWindData.swift
//  Skewt
//
//  Created by Jason Neel on 11/10/23.
//

import Foundation

enum WindShearError: Error {
    case missingWindData
}

struct WindShear {
    let below: LevelDataPoint
    let above: LevelDataPoint
    
    init(_ a: LevelDataPoint, _ b: LevelDataPoint) throws {
        guard a.windDirection != nil, a.windSpeed != nil, b.windDirection != nil, b.windSpeed != nil else {
            throw WindShearError.missingWindData
        }
        
        below = a
        above = b
    }
    
    var shear: (n: Double, e: Double) {
        let winds = [below.windComponents!, above.windComponents!]
        
        return (n: winds[1].n - winds[0].n, e: winds[1].e - winds[0].e)
    }
    
    var shearPerAltitude: (n: Double, e: Double) {
        let shear = self.shear
        let dPressureAltitude: Altitude = .standardAltitude(forPressure: above.pressure) - .standardAltitude(forPressure: below.pressure)
        
        return (n: shear.n / dPressureAltitude, e: shear.e / dPressureAltitude)
    }
}

extension LevelDataPoint {
    var windComponents: (n: Double, e: Double)? {
        guard let windSpeed = windSpeed, let windDirection = windDirection else {
            return nil
        }
        
        let speed = Double(windSpeed)
        let direction = Double(windDirection) * .pi / 180.0
        
        return (n: speed * cos(direction), e: speed * sin(direction))
    }
}

extension Sounding {
    /// All data points in the sounding that contain wind data
    var windData: [LevelDataPoint] {
        data.filter { $0.windSpeed != nil && $0.windDirection != nil }
    }
    
    /// Wind data as north/east components
    var windDataDirectionalComponents: [(n: Double, e: Double)] {
        windData.map { $0.windComponents! }
    }
    
    var windShearData: [WindShear] {
        let windData = windData
        
        return stride(from: 0, to: windData.count - 1, by: 1).compactMap {
            try? WindShear(windData[$0], windData[$0 + 1])
        }
    }
}
