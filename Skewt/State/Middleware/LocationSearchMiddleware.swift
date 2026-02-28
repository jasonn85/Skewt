//
//  LocationSearchMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 7/8/23.
//

import Foundation
import Combine
import CoreLocation
import OSLog

extension CLLocation {
    static let denver = CLLocation(latitude: 39.87, longitude: -104.67)
}

extension Middlewares {
    static let locationSearchLogger = Logger()
    private static let locationSearchQueue = DispatchQueue(label: "com.skewt.locationSearch",
                                                           target: .global(qos: .userInitiated))
    private enum SearchType {
        case location(CLLocation)
        case text(String)
    }
    
    static let locationSearchMiddleware: Middleware<SkewtState> = { _, state, action in
        if case .didDetermineLocation(let location) = action as? LocationState.Action,
           case .loading = state.displayState.forecastSelectionState.searchStatus {
            // We were waiting on location and just got it
            return search(withState: state)
        }
        
        switch action as? ForecastSelectionState.Action {
        case .setSearchText(let text):
            return debouncedLoadPublisher(for: text)
        case .load:
            return search(withState: state)
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
    
    private static func search(withState state: SkewtState) -> AnyPublisher<Action, Never> {
        let defaultLocation = CLLocation.denver
        var searchType: SearchType
        var forecastSearchType: ForecastSelectionState.SearchType
        
        if case .text(let text) = state.displayState.forecastSelectionState.searchType, text.count > 0 {
            searchType = .text(text)
            forecastSearchType = .text(text)
        } else {
            var location = state.locationState.locationIfKnown
            
            if location == nil {
                switch state.locationState.status {
                case .locationRequestFailed, .permissionDenied:
                    location = defaultLocation
                case .locationKnown(_, _, _):
                    locationSearchLogger.error("Location is both known and unknown? Something broke.")
                    fallthrough
                case .requestingPermission, .none:
                    // We're still waiting on location info. Chill for now.
                    return Empty().eraseToAnyPublisher()
                }
            }
            
            searchType = .location(location!)
            forecastSearchType = .nearest
        }
        
        return Deferred {
            Just({
                let locations = LocationList.allLocations

                switch searchType {
                case .location(let location):
                    return locations.locationsSortedByProximity(to: location)
                case .text(let text):
                    return locations.locationsForSearch(text)
                }
            }())
        }
        .subscribe(on: locationSearchQueue)
        .map { ForecastSelectionState.Action.didFinishSearch(forecastSearchType, $0) }
        .eraseToAnyPublisher()
    }

    private static func debouncedLoadPublisher(for text: String?) -> AnyPublisher<Action, Never> {
        Just(text)
            .delay(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .map { _ in ForecastSelectionState.Action.load as Action }
            .eraseToAnyPublisher()
    }
}
