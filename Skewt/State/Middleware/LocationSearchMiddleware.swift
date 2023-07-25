//
//  LocationSearchMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 7/8/23.
//

import Foundation
import Combine
import CoreLocation

extension CLLocation {
    static var denver = CLLocation(latitude: 39.87, longitude: -104.67)
}

extension Middlewares {
    static let locationSearchMiddleware: Middleware<SkewtState> = { state, action in
        let defaultLocation = CLLocation.denver
        
        switch action as? ForecastSelectionState.Action {
        case .setSearchText(let text):
            return LocationSearchManager.shared.search(text)
                .map { _ in
                    ForecastSelectionState.Action.load
                }
                .eraseToAnyPublisher()
        case .load:
            var searchType: LocationSearchManager.SearchType
            var forecastSearchType: ForecastSelectionState.SearchType
            
            if case .text(let text) = state.displayState.forecastSelectionState.searchType, text.count > 0 {
                searchType = .text(text)
                forecastSearchType = .text(text)
            } else {
                searchType = .location(state.locationState.locationIfKnown ?? defaultLocation)
                forecastSearchType = .nearest
            }
            
            return LocationSearchManager.shared.locationSearchPublisher(forType: searchType)
                .map { ForecastSelectionState.Action.didFinishSearch(forecastSearchType, $0) }
                .eraseToAnyPublisher()
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
}

class LocationSearchManager {
    static let shared = LocationSearchManager()
    
    private let searchText = CurrentValueSubject<String?, Never>("")
    private var searchDebouncePublisher: AnyCancellable!
    private var searchDidDebouncePublisher: PassthroughSubject<String?, Never>? = nil
    
    private let searchQueue = DispatchQueue(label: "com.skewt.locationSearch")
    
    enum SearchType {
        case location(CLLocation)
        case text(String)
    }
    
    init() {
        // Set to nil so we can reference self when properly initializing it below
        searchDebouncePublisher = nil
        
        searchDebouncePublisher = searchText
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
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
