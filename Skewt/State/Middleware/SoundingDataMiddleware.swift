//
//  SoundingDataMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 2/18/26.
//

import Foundation
import Combine
import CoreLocation
import OSLog

extension Middlewares {
    private static let soundingParseQueue = DispatchQueue(label: "skewt.sounding.parse", qos: .utility)

    static let ncafSoundingData: Middleware<SkewtState> = { oldState, state, action in
        guard case .ncaf(let selection) = state.currentSoundingState.loadIntent else {
            return Empty().eraseToAnyPublisher()
        }

        guard oldState.currentSoundingState.loadIntent != state.currentSoundingState.loadIntent else {
            return Empty().eraseToAnyPublisher()
        }

        guard case .sounding = selection.type else {
            return Empty().eraseToAnyPublisher()
        }
        
        let url = NCAFSoundingList.url
        Logger().info("Requesting soundings from NCAF via \(url.absoluteString)")

        return URLSession.shared.dataTaskPublisher(for: NCAFSoundingList.url)
            .subscribe(on: soundingParseQueue)
            .map { data, response in
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8),
                      let list = NCAFSoundingList(fromString: text) else {
                    return SoundingState.Action.requestFailed(.unparseableResponse)
                }

                return SoundingState.Action.ncafLoaded(list)
            }
            .replaceError(with: SoundingState.Action.requestFailed(.requestFailed))
            .eraseToAnyPublisher()
    }

    static let uwySoundingData: Middleware<SkewtState> = { oldState, state, action in
        guard case .uwy(let selection) = state.currentSoundingState.loadIntent else {
            return Empty().eraseToAnyPublisher()
        }

        guard oldState.currentSoundingState.loadIntent != state.currentSoundingState.loadIntent else {
            return Empty().eraseToAnyPublisher()
        }

        guard case .sounding = selection.type else {
            return Empty().eraseToAnyPublisher()
        }

        if selection.requiresLocation, state.locationState.locationIfKnown == nil {
            return Just(SoundingState.Action.requestFailed(.lackingLocationPermission))
                .eraseToAnyPublisher()
        }

        guard let stationId = stationId(for: selection, currentLocation: state.locationState.locationIfKnown) else {
            return Just(SoundingState.Action.requestFailed(.unableToGenerateRequestFromSelection))
                .eraseToAnyPublisher()
        }

        let request = UWYSoundingRequest(stationId: stationId, time: uwyTime(for: selection))
        let url = request.url
        
        Logger().info("Request soundings from UWY API via \(url.absoluteString)")

        return URLSession.shared.dataTaskPublisher(for: url)
            .subscribe(on: soundingParseQueue)
            .map { data, response in
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8),
                      let sounding = UWYSounding(fromCsvString: text, soundingTime: request.time.date) else {
                    return SoundingState.Action.requestFailed(.unparseableResponse)
                }

                return SoundingState.Action.uwyLoaded(sounding)
            }
            .replaceError(with: SoundingState.Action.requestFailed(.requestFailed))
            .eraseToAnyPublisher()
    }
}

private extension Middlewares {
    static func stationId(for selection: SoundingSelection, currentLocation: CLLocation?) -> Int? {
        switch selection.location {
        case .closest:
            guard let location = currentLocation else {
                return nil
            }

            guard let list = try? LocationList.forType(.sounding) else {
                return nil
            }

            return list.locationsSortedByProximity(to: location).first { $0.wmoId != nil }?.wmoId

        case .named(let name, let latitude, let longitude):
            if let list = try? LocationList.forType(.sounding) {
                if let location = list.locationNamed(name, latitude: latitude, longitude: longitude),
                   let wmoId = location.wmoId {
                    return wmoId
                }

                if let wmoId = list.locations.first(where: { $0.name == name && $0.wmoId != nil })?.wmoId {
                    return wmoId
                }
            }

            if let location = LocationList.allLocations.locationNamed(name, latitude: latitude, longitude: longitude),
               let wmoId = location.wmoId {
                return wmoId
            }

            return LocationList.allLocations
                .locations
                .first(where: { $0.name == name && $0.wmoId != nil })?.wmoId

        case .point(let latitude, let longitude):
            guard let list = try? LocationList.forType(.sounding) else {
                return nil
            }

            let location = CLLocation(latitude: latitude, longitude: longitude)
            return list.locationsSortedByProximity(to: location).first { $0.wmoId != nil }?.wmoId
        }
    }

    static func uwyTime(for selection: SoundingSelection) -> UWYSoundingRequest.SoundingTime {
        let date = selection.timeAsConcreteDate
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt

        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let hour = components.hour ?? 0
        let time: UWYSoundingRequest.SoundingTime.Time = hour >= 12 ? .utc1200 : .utc0000

        return UWYSoundingRequest.SoundingTime(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1,
            time: time
        )
    }
}
