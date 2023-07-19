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
    private static let defaultLocation = CLLocation.denver
    
    static let locationSearchMiddleware: Middleware<SkewtState> = { state, action in
        switch action as? ForecastSelectionState.Action {
        case .setSearchText(let text):
            return LocationSearchManager.shared.search(text)
                .handleEvents(receiveOutput: {
                    print("debounce happened: \($0)")
                })
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
    private var searchDebouncePublisher: AnyPublisher<String?, Never>
    
    init() {
        searchDebouncePublisher = searchText
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .dropFirst()
            .eraseToAnyPublisher()
    }
    
    private let searchQueue = DispatchQueue(label: "com.skewt.locationSearch")
    
    enum SearchType {
        case location(CLLocation)
        case text(String)
    }
    
    @discardableResult
    func search(_ text: String?) -> AnyPublisher<String?, Never> {
        searchText.send(text)
        
        return searchDebouncePublisher
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
