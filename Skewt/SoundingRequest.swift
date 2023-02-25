//
//  SoundingRequest.swift
//  Skewt
//
//  Created by Jason Neel on 2/23/23.
//

import Foundation

struct SoundingRequest {
    let location: Location
    let modelName: SoundingType?
    let startTime: Date?
    let endTime: Date?
    let numberOfHours: Int?
    
    init(location: Location,
         modelName: SoundingType? = nil,
         startTime: Date? = nil,
         endTime: Date? = nil,
         numberOfHours: Int? = nil) {
        self.location = location
        self.modelName = modelName
        self.startTime = startTime
        self.endTime = endTime
        self.numberOfHours = numberOfHours
    }
}

enum Location {
    case name(String)
    case geolocation(latitude: Double, longitude: Double)
}
