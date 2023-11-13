//
//  SoundingWindData.swift
//  Skewt
//
//  Created by Jason Neel on 11/10/23.
//

import Foundation

extension Sounding {
    /// All data points in the sounding that contain wind data
    var windData: [LevelDataPoint] {
        data.filter { $0.windSpeed != nil && $0.windDirection != nil }
    }
    
    /// Wind data as north/east components
    var windDataDirectionalComponents: [(n: Double, e: Double)] {
        windData.map {
            let speed = Double($0.windSpeed!)
            let direction = Double($0.windDirection!) * .pi / 180.0
            
            return (n: speed * cos(direction), e: speed * sin(direction))
        }
    }
}
