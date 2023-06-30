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
    case unableToFindClosestSounding
}

extension Middlewares {
    static let rucApi: Middleware<SkewtState> = { state, action in
        switch action as? SoundingState.Action {
        case .doRefresh, .changeAndLoadSelection(_):
            let selection = state.currentSoundingState.selection
            let location = state.locationState.locationIfKnown
            
            guard !selection.requiresLocation || location != nil else {
                return Just(SoundingState.Action.didReceiveFailure(.lackingLocationPermission))
                    .eraseToAnyPublisher()
            }
            
            guard let soundingRequest = try? SoundingRequest(fromSoundingSelection: selection,
                                                             currentLocation: location,
                                                             recentSoundings: state.recentSoundingsState.recentSoundings) else {
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

extension LatestSoundingList {
    func soundingRequestLocation(forSelectionLocation selectionLocation: SoundingSelection.Location,
                                 currentLocation: CLLocation?) throws -> SoundingRequest.Location {
        var searchLocation: CLLocation
        let recentSoundingIds = recentSoundings().compactMap { $0.wmoIdOrNil }
        
        switch selectionLocation {
        case .closest:
            guard let currentLocation = currentLocation else {
                throw RucRequestError.missingCurrentLocation
            }
            
            searchLocation = currentLocation
        case .point(latitude: let latitude, longitude: let longitude):
            searchLocation = CLLocation(latitude: latitude, longitude: longitude)
        case .named(let name):
            if let soundingLocation = try? LocationList.forType(.raob).locations.first(where:{ $0.name == name }) {
                if let wmoId = soundingLocation.wmoId,
                   recentSoundingIds.contains(wmoId) {
                    // This site name corresponds to an active sounding site. Use it.
                    return .name(name)
                } else {
                    // This is a sounding site that has _not_ had a recent sounding
                    searchLocation = CLLocation(latitude: soundingLocation.latitude,
                                                longitude: soundingLocation.longitude)
                }
            } else {
                guard let location = try? LocationList.forType(.op40).locations.first(where: { $0.name == name }) else {
                    throw RucRequestError.unableToFindClosestSounding
                }
                
                searchLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            }
        }
        
        // We now have a location that does not directly correspond to a sounding location.
        // Find the closest active sounding location.
        guard let location = try? LocationList.forType(.raob)
            .locationsSortedByProximity(to: searchLocation, onlyWmoIds: recentSoundingIds)
            .first else {
            
            throw RucRequestError.unableToFindClosestSounding
        }
        
        return .name(location.name)
    }
}

extension SoundingRequest {
    init(fromSoundingSelection selection: SoundingSelection,
         currentLocation: CLLocation? = nil,
         recentSoundings: LatestSoundingList? = nil) throws {
        var location: SoundingRequest.Location
        var modelType: SoundingType
        var startTime: Date?
        var endTime: Date?
        
        switch selection.type {
        case .raob:
            guard let recentSoundings = recentSoundings else {
                throw RucRequestError.unableToFindClosestSounding
            }
            
            modelType = .raob
            location = try recentSoundings.soundingRequestLocation(
                forSelectionLocation: selection.location,
                currentLocation: currentLocation
            )
        case .op40:
            modelType = .op40
            
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
        }
        
        switch selection.time {
        case .now:
            startTime = nil
        case .relative(let timeInterval):
            startTime = Date(timeIntervalSinceNow: timeInterval)
            endTime = Date(timeIntervalSinceNow: timeInterval + .hours(1))
        case .specific(let date):
            startTime = date
        }
        
        self.init(location: location, modelName: modelType, startTime: startTime, endTime: endTime)
    }
}
