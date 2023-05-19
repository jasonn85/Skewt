//
//  RucApiMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation
import Combine
import CoreLocation

enum RucRequestError: Error {
    case missingCurrentLocation
}

extension Middlewares {
    static let rucApi: Middleware<State> = { state, action in
        guard let action = action as? SoundingState.Action else {
            return Empty().eraseToAnyPublisher()
        }

        switch action {
        case .doRefresh, .changeAndLoadSelection(_):
            let selection = state.currentSoundingState.selection
            var location: CLLocation? = nil
            
            guard !selection.requiresLocation || state.locationState.isLocationKnown else {
                return Just(SoundingState.Action.didReceiveFailure(.lackingLocationPermission))
                    .eraseToAnyPublisher()
            }
                        
            if case .locationKnown(
                latitude: let latitude,
                longitude: let longitude,
                time: _
            ) = state.locationState.status {
                location = CLLocation(latitude: latitude, longitude: longitude)
            }
            
            guard let soundingRequest = try? SoundingRequest(fromSoundingSelection: selection, currentLocation: location) else {
                return Just(SoundingState.Action.didReceiveFailure(.unableToGenerateRequestFromSelection))
                    .eraseToAnyPublisher()
            }
        
            return URLSession.shared.dataTaskPublisher(for: soundingRequest.url)
                .map { data, response in
                    guard !data.isEmpty,
                          let text = String(data: data, encoding: .utf8),
                          let sounding = try? Sounding(fromText: text) else {
                        return SoundingState.Action.didReceiveFailure(.unparseableResponse)
                    }
                    
                    return SoundingState.Action.didReceiveResponse(sounding)
                }
                .replaceError(with: SoundingState.Action.didReceiveFailure(.requestFailed))
                .eraseToAnyPublisher()
            
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
}

extension SoundingRequest {
    init(fromSoundingSelection selection: SoundingSelection, currentLocation: CLLocation? = nil) throws {
        var location: SoundingRequest.Location
        var modelType: SoundingType
        var startTime: Date?
        
        switch selection.location {
        case .closest:
            guard let currentLocation = currentLocation else {
                throw RucRequestError.missingCurrentLocation
            }
            
            location = .geolocation(latitude: currentLocation.coordinate.latitude,
                                    longitude: currentLocation.coordinate.longitude)
        case .point(latitude: let latitude, longitude: let longitude):
            location = .geolocation(latitude: latitude, longitude: longitude)
        case .named(let locationName):
            location = .name(locationName)
        }
        
        switch selection.type {
        case .op40:
            modelType = .op40
        case .raob:
            modelType = .raob
        }
        
        switch selection.time {
        case .now:
            startTime = nil
        case .relative(let timeInterval):
            startTime = Date(timeIntervalSinceNow: timeInterval)
        case .specific(let date):
            startTime = date
        }
        
        self.init(location: location, modelName: modelType, startTime: startTime)
    }
}
