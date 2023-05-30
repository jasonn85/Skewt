//
//  LocationState.swift
//  Skewt
//
//  Created by Jason Neel on 5/18/23.
//

import Foundation
import CoreLocation

struct LocationState: Codable {
    enum Status: Codable {
        case requestingPermission
        case permissionDenied
        case locationRequestFailed
        case locationKnown(latitude: Double, longitude: Double, time: Date)
    }
    
    enum Action: Skewt.Action {
        case requestLocation
        case permissionWasDenied
        case locationRequestDidFail
        case didDetermineLocation(CLLocation)
    }
    
    let status: Status?
}

extension LocationState {
    var locationIfKnown: CLLocation? {
        switch status {
        case .locationKnown(let latitude, let longitude, _):
            return CLLocation(latitude: latitude, longitude: longitude)
        default:
            return nil
        }
    }
}

extension LocationState {
    init() {
        status = nil
    }
}

extension LocationState.Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .requestLocation:
            return "Requesting location"
        case .permissionWasDenied:
            return "Location permission was denied"
        case .locationRequestDidFail:
            return "Location request failed"
        case .didDetermineLocation(_):
            return "Location acquired"
        }
    }
}

extension LocationState {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? LocationState.Action else {
            return state
        }
        
        switch action {
        case .permissionWasDenied:
            return LocationState(status: .permissionDenied)
        case .locationRequestDidFail:
            return LocationState(status: .locationRequestFailed)
        case .didDetermineLocation(let location):
            return LocationState(status: .locationKnown(latitude: location.coordinate.latitude,
                                                        longitude: location.coordinate.longitude,
                                                        time: Date()))
        default:
            return state
        }
    }
}


