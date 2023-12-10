//
//  SoundingWindData.swift
//  Skewt
//
//  Created by Jason Neel on 11/10/23.
//

import Foundation

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
}

struct ReducedWindDataPoint {
    let pressure: Double
    let windMagnitude: Double
}

extension Sounding {
    typealias WindReducer = (Int, Int) -> Double
    
    static var magnitudeWindReducer: WindReducer = { _, speed in Double(speed) }
    
    func maximumWindReducer() -> WindReducer {
        let windData = windData
        
        guard windData.count > 0 else {
            return Sounding.magnitudeWindReducer
        }
        
        let maximumWindPoint = windData.reduce(windData.first!) { $1.windSpeed! > $0.windSpeed! ? $1 : $0 }
        var maximumWindAngle = Double(maximumWindPoint.windDirection!) * .pi / 180.0
        
        if maximumWindAngle >= .pi {
            maximumWindAngle -= .pi
        }
        
        return { direction, speed in
            let thisAngle = Double(direction) * .pi / 180.0
            
            return cos(thisAngle - maximumWindAngle) * Double(speed)
        }
    }
    
    func reducedWindData(_ reducer: WindReducer) -> [ReducedWindDataPoint] {
        windData.map {
            ReducedWindDataPoint(pressure: $0.pressure, windMagnitude: reducer($0.windDirection!, $0.windSpeed!))
        }
    }
}
