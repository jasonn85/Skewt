//
//  LocationSearchMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 7/8/23.
//

import Foundation
@preconcurrency import Combine
import CoreLocation
import OSLog

extension CLLocation {
    static let denver = CLLocation(latitude: 39.87, longitude: -104.67)
}

extension Middlewares {
    static let locationSearchLogger = Logger()
    private static let locationSearchQueue = DispatchQueue(label: "com.skewt.locationSearch",
                                                           target: .global(qos: .userInitiated))
    
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
        Deferred {
            let subject = PassthroughSubject<Action, Never>()
            let cancellableBox = SearchCancellableBox()

            Task { @MainActor in
                cancellableBox.cancellable = LocationSearchManager.shared.search(text)
                    .map { _ in ForecastSelectionState.Action.load as Action }
                    .sink(
                        receiveCompletion: { _ in
                            subject.send(completion: .finished)
                            cancellableBox.cancellable = nil
                        },
                        receiveValue: { subject.send($0) }
                    )
            }

            return subject
        }
        .eraseToAnyPublisher()
    }
}

final class LocationSearchManager {
    @MainActor static let shared = LocationSearchManager()
    
    private var pendingDebounceWorkItem: DispatchWorkItem?
    private var pendingSubject: PassthroughSubject<String?, Never>?
    
    enum SearchType {
        case location(CLLocation)
        case text(String)
    }
    
    init() {}
    
    @discardableResult
    func search(_ text: String?) -> AnyPublisher<String?, Never> {
        pendingDebounceWorkItem?.cancel()
        pendingDebounceWorkItem = nil

        pendingSubject?.send(completion: .finished)

        let subject = PassthroughSubject<String?, Never>()
        pendingSubject = subject

        let workItem = DispatchWorkItem { [weak self] in
            subject.send(text)
            subject.send(completion: .finished)

            guard let self else { return }
            if self.pendingSubject === subject {
                self.pendingSubject = nil
            }
            self.pendingDebounceWorkItem = nil
        }
        pendingDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)

        return subject.eraseToAnyPublisher()
    }
    
}

private final class SearchCancellableBox {
    var cancellable: AnyCancellable?
}
