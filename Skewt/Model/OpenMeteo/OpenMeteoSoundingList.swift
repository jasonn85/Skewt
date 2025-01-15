//
//  OpenMeteoSoundingList.swift
//  Skewt
//
//  Created by Jason Neel on 11/4/24.
//

import Foundation
import CoreLocation

struct OpenMeteoSounding: Sounding {
    let date: Date
    let fetchTime: Date
    let latitude: Double
    let longitude: Double
    
    let data: SoundingData
}

struct OpenMeteoSoundingList: Codable, Equatable {
    let fetchTime: Date
    let latitude: Double
    let longitude: Double
    
    let data: [Date: SoundingData]
    
    func closestSounding(toDate date: Date = .now) -> OpenMeteoSounding? {
        guard data.count > 0 else {
            return nil
        }
        
        let soundingDate = data.keys.reduce(data.keys.first!) {
            abs(date.timeIntervalSince($0)) < abs(date.timeIntervalSince($1)) ? $0 : $1
        }
        
        return OpenMeteoSounding(
            date: soundingDate,
            fetchTime: fetchTime,
            latitude: latitude,
            longitude: longitude,
            data: data[soundingDate]!
        )
    }
}


