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
    static var denver = CLLocation(latitude: 39.87, longitude: -104.67)
}

extension Middlewares {
    static let locationSearchLogger = Logger()
    
    static let locationSearchMiddleware: Middleware<SkewtState> = { state, action in
        if case .didDetermineLocation(let location) = action as? LocationState.Action,
           case .loading = state.displayState.forecastSelectionState.searchStatus {
            // We were waiting on location and just got it
            return search(withState: state)
        }
        
        switch action as? ForecastSelectionState.Action {
        case .setSearchText(let text):
            return LocationSearchManager.shared.search(text)
                .map { _ in
                    ForecastSelectionState.Action.load
                }
                .eraseToAnyPublisher()
        case .load:
            return search(withState: state)
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
    
    private static func search(withState state: SkewtState) -> AnyPublisher<Action, Never> {
        let defaultLocation = CLLocation.denver
        var searchType: LocationSearchManager.SearchType
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
        
        return LocationSearchManager.shared.locationSearchPublisher(forType: searchType)
            .map { ForecastSelectionState.Action.didFinishSearch(forecastSearchType, $0) }
            .eraseToAnyPublisher()
    }
}

class LocationSearchManager {
    static let shared = LocationSearchManager()
    
    private let searchText = CurrentValueSubject<String?, Never>("")
    private var searchDebouncePublisher: AnyCancellable!
    private var searchDidDebouncePublisher: PassthroughSubject<String?, Never>? = nil
    
    private let searchQueue = DispatchQueue(label: "com.skewt.locationSearch",
                                            target: .global(qos: .userInitiated))
    
    enum SearchType {
        case location(CLLocation)
        case text(String)
    }
    
    init() {
        // Set to nil so we can reference self when properly initializing it below
        searchDebouncePublisher = nil
        
        searchDebouncePublisher = searchText
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .removeDuplicates()
            .dropFirst()
            .sink {
                self.searchDidDebouncePublisher?.send($0)
                self.searchDidDebouncePublisher = nil
            }
    }
    
    @discardableResult
    func search(_ text: String?) -> AnyPublisher<String?, Never> {
        searchDidDebouncePublisher?.send(completion: .finished)
        searchDidDebouncePublisher = PassthroughSubject()
        
        searchText.send(text)
        
        return searchDidDebouncePublisher!.eraseToAnyPublisher()
    }
    
    func locationSearchPublisher(forType type: SearchType) -> AnyPublisher<[LocationList.Location], Never> {
        let publisher = PassthroughSubject<[LocationList.Location], Never>()
        
        searchQueue.async {
            let locations = LocationList.allLocations

            switch type {
            case .location(let location):
                publisher.send(locations.locationsSortedByProximity(to: location))
            case .text(let text):
                publisher.send(locations.locationsForSearch(text))
            }
        }

        return publisher.eraseToAnyPublisher()
    }
}
