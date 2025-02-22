//
//  RucApiMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation
import Combine
import CoreLocation
import OSLog

enum RucRequestError: Error {
    case missingCurrentLocation
    case unableToFindClosestSounding
}

extension Middlewares {
//    static let rucApi: Middleware<SkewtState> = { state, action in
//        let logger = Logger()
//        
//        switch action as? RecentSoundingsState.Action {
//        case .didReceiveList(_):
//            switch state.currentSoundingState.status {
//            case .awaitingSoundingLocationData:
//                return Just(SoundingState.Action.doRefresh).eraseToAnyPublisher()
//            default:
//                break
//            }
//        default:
//            break
//        }
//        
//        switch action as? SoundingState.Action {
//        case .doRefresh, .changeAndLoadSelection(_):
//            let selection = state.currentSoundingState.selection
//            let location = state.locationState.locationIfKnown
//            
//            guard !selection.requiresLocation || location != nil else {
//                return Just(SoundingState.Action.didReceiveFailure(.lackingLocationPermission))
//                    .eraseToAnyPublisher()
//            }
//            
//            do {
//                let soundingRequest = try RucSoundingRequest(fromSoundingSelection: selection,
//                                                             currentLocation: location,
//                                                             recentSoundings: state.recentSoundingsState.recentSoundings)
//                let url = soundingRequest.url
//                
//                logger.info("Requesting a sounding via \(url.absoluteString)")
//                
//                return URLSession.shared.dataTaskPublisher(for: url)
//                    .map { data, response in
//                        guard !data.isEmpty,
//                                let text = String(data: data, encoding: .utf8),
//                                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
//                            return SoundingState.Action.didReceiveFailure(.emptyResponse)
//                        }
//                        
//                        guard let sounding = try? RucSounding(fromText: text) else {
//                            return SoundingState.Action.didReceiveFailure(.unparseableResponse)
//                        }
//                        
//                        return SoundingState.Action.didReceiveResponse(sounding)
//                    }
//                    .replaceError(with: SoundingState.Action.didReceiveFailure(.requestFailed))
//                    .eraseToAnyPublisher()
//            } catch RucRequestError.unableToFindClosestSounding {
//                return Just(SoundingState.Action.awaitSoundingLocation).eraseToAnyPublisher()
//            } catch {
//                return Just(SoundingState.Action.didReceiveFailure(.unableToGenerateRequestFromSelection))
//                    .eraseToAnyPublisher()
//            }
//            
//        default:
//            return Empty().eraseToAnyPublisher()
//        }
//    }
}

extension LatestSoundingList {
    func soundingRequestLocation(forSelectionLocation selectionLocation: SoundingSelection.Location,
                                 currentLocation: CLLocation?) throws -> RucSoundingRequest.Location {
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
        case .named(let name, _, _):
            if let soundingLocation = try? LocationList.forType(.raob).locationNamed(name) {
                if let wmoId = soundingLocation.wmoId,
                   recentSoundingIds.contains(wmoId) {
                    // This site name corresponds to an active sounding site. Use it.
                    return .name(name)
                } else {
                    // This is a sounding site that has _not_ had a recent sounding
                    searchLocation = soundingLocation.clLocation
                }
            } else {
                guard let location = try? LocationList.forType(.automaticForecast).locationNamed(name) else {
                    throw RucRequestError.unableToFindClosestSounding
                }
                
                searchLocation = location.clLocation
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

extension RucSoundingRequest {
    init(fromSoundingSelection selection: SoundingSelection,
         currentLocation: CLLocation? = nil,
         recentSoundings: LatestSoundingList? = nil) throws {
        var location: RucSoundingRequest.Location
        var modelType: RucSounding.SoundingType
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
        case .automaticForecast:
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
            case .named(let locationName, _, _):
                location = .name(locationName)
            }
        }
        
        switch selection.time {
        case .now:
            startTime = Date.nearestHour(withIntervalFromNow: 0, hoursPerInterval: selection.type.hourInterval)
            endTime = startTime!.addingTimeInterval(.hours(selection.type.hourInterval))
        case .relative(let timeInterval):
            switch selection.type {
            case .automaticForecast:
                startTime = Date.nearestHour(withIntervalFromNow: timeInterval, hoursPerInterval: selection.type.hourInterval)
                endTime = startTime!.addingTimeInterval(.hours(selection.type.hourInterval))
            case .raob:
                startTime = timeInterval.closestSoundingTime()
            }
        case .numberOfSoundingsAgo(let pastSoundingIndex):
            startTime = Date.mostRecentSoundingTimes(
                count: pastSoundingIndex,
                soundingIntervalInHours: selection.type.hourInterval
            )[pastSoundingIndex - 1]
        case .specific(let date):
            startTime = date
        }
        
        self.init(location: location, modelName: modelType, startTime: startTime, endTime: endTime)
    }
}
