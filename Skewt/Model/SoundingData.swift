//
//  SoundingData.swift
//  Skewt
//
//  Created by Jason Neel on 10/26/24.
//

import Foundation

struct SoundingData: Codable {
    struct Point: Codable {
        let pressure: Double?
        let height: Int?
        let temperature: Double?
        let dewPoint: Double?
        let windDirection: Int?
        let windSpeed: Double?
    }
    
    let time: Date
    let dataPoints: [Point]
    
    let cape: Int?  // Convective Available Potential Energy in J/Kg
    let cin: Int?  // Convective Inhibition in J/Kg
    let helicity: Int?  // Storm-relative helicity in m^2/s^2
    let precipitableWater: Int?  // Precipitable water in model column in Kg/m^2
}
