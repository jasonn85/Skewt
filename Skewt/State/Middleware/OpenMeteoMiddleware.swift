//
//  OpenMeteoMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 12/29/24.
//

import Foundation
import Combine
import OSLog
import CoreLocation

enum OpenMeteoRequestError: Error {
    case unsupportedModel
    case unsupportedLocationType
    case missingLocation
}

extension Middlewares {
    static let openMeteoApi: Middleware<SkewtState> = { oldState, state, action in
        let logger = Logger()
        guard case .openMeteo(let selection) = state.currentSoundingState.loadIntent else {
            return Empty().eraseToAnyPublisher()
        }

        guard oldState.currentSoundingState.loadIntent != state.currentSoundingState.loadIntent else {
            return Empty().eraseToAnyPublisher()
        }

        switch selection.type {
        case .sounding:
            // Open-Meteo is forecast only
            return Empty().eraseToAnyPublisher()
        case .forecast:
            break
        }

        guard !selection.requiresLocation || state.locationState.locationIfKnown != nil else {
            return Just(SoundingState.Action.requestFailed(.lackingLocationPermission))
                .eraseToAnyPublisher()
        }

        guard let request = try? OpenMeteoSoundingListRequest(
            fromSoundingSelection: selection,
            currentLocation: state.locationState.locationIfKnown
        ) else {
            return Just(SoundingState.Action.requestFailed(.unableToGenerateRequestFromSelection))
                .eraseToAnyPublisher()
        }

        let url = request.url

        logger.info("Request soundings from Open-Meteo via \(url.absoluteString)")

        return URLSession.shared.dataTaskPublisher(for: url)
            .map { data, response in
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return SoundingState.Action.requestFailed(.emptyResponse)
                }

                guard let soundingList = try? OpenMeteoSoundingList(fromData: data) else {
                    return SoundingState.Action.requestFailed(.unparseableResponse)
                }

                return SoundingState.Action.openMeteoLoaded(soundingList)
            }
            .replaceError(with: SoundingState.Action.requestFailed(.requestFailed))
            .eraseToAnyPublisher()
    }
}

extension OpenMeteoSoundingListRequest {
    init(fromSoundingSelection selection: SoundingSelection, currentLocation: CLLocation? = nil) throws {
        let latitude: Double
        let longitude: Double
        
        switch selection.location {
        case .closest:
            guard let location = currentLocation else {
                throw OpenMeteoRequestError.missingLocation
            }
            
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        case .point(let pointLatitude, let pointLongitude),
                .named(_, let pointLatitude, let pointLongitude):
            latitude = pointLatitude
            longitude = pointLongitude
        }
        
        let startHour: Date?
        
        switch selection.time {
        case .now:
            startHour = nil
        case .numberOfSoundingsAgo(let soundingsAgoCount):
            startHour = .now.addingTimeInterval(-Double(soundingsAgoCount) * 60.0 * 60.0)
        case .relative(let interval):
            startHour = .now.addingTimeInterval(interval)
        case .specific(let date):
            startHour = date
        }
        
        self.init(
            latitude: latitude,
            longitude: longitude,
            hourly: OpenMeteoSoundingListRequest.HourlyValue.skewtHourlyValues,
            forecast_hours: 12,
            past_hours: 12,
            start_hour: startHour
        )
    }
}

extension OpenMeteoSoundingListRequest.HourlyValue {
    static var skewtHourlyValues: [OpenMeteoSoundingListRequest.HourlyValue] {
        allTemperatures + allDewPoints + allWindSpeeds + allWindDirections + allGeopotentialHeights + [.surface_pressure]
    }
}
