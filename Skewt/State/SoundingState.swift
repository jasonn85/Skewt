//
//  SoundingState.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct SoundingSelection: Codable {
    enum ModelType: Codable {
        case op40
        case raob
    }
    
    enum Location: Codable {
        case closest
        case point(latitude: Double, longitude: Double)
        case named(String)
    }
    
    enum Time: Codable {
        case now
        case relative(TimeInterval)
        case specific(Date)
    }
    
    let type: ModelType
    let location: Location
    let time: Time
}

extension SoundingSelection {
    init() {
        type = .op40
        location = .closest
        time = .now
    }
}

struct SoundingState: Codable {
    enum SoundingError: Error, Codable {
        // TODO: Implement
        case unknown
    }
    
    enum Status: Codable {
        case idle
        case loading
        case done(Sounding)
        case refreshing(Sounding)
        case failed(SoundingError)
    }
    
    let selection: SoundingSelection
    let status: Status
}

extension SoundingState {
    init() {
        selection = SoundingSelection()
        status = .idle
    }
}
