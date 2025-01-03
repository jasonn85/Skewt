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
    static let openMeteoApi: Middleware<SkewtState> = { state, action in
        let logger = Logger()
        
        switch state.currentSoundingState.status {
        case .loading, .refreshing(_):
            guard !state.currentSoundingState.selection.requiresLocation || state.locationState.locationIfKnown != nil else {
                return Just(SoundingState.Action.didReceiveFailure(.lackingLocationPermission))
                                .eraseToAnyPublisher()
            }
            
            guard let request = try? OpenMeteoSoundingListRequest(
                fromSoundingSelection: state.currentSoundingState.selection,
                currentLocation: state.locationState.locationIfKnown
            ) else {
                return Just(SoundingState.Action.didReceiveFailure(.unableToGenerateRequestFromSelection))
                    .eraseToAnyPublisher()
            }
            
            let url = request.url
            
            logger.info("Request soundings from Open-Meteo via \(url.absoluteString)")
            
            return URLSession.shared.dataTaskPublisher(for: url)
                .map { data, response in
                    guard !data.isEmpty,
                          let text = String(data: data, encoding: .utf8),
                          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return SoundingState.Action.didReceiveFailure(.emptyResponse)
                    }
                    
                    guard let soundingList = try? OpenMeteoSoundingList(fromData: data) else {
                        return SoundingState.Action.didReceiveFailure(.unparseableResponse)
                    }

                    return SoundingState.Action.didReceiveResponse(soundingList)
                }
                .replaceError(with: SoundingState.Action.didReceiveFailure(.requestFailed))
                .eraseToAnyPublisher()
            
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
}

extension OpenMeteoSoundingListRequest {
    init(fromSoundingSelection selection: SoundingSelection, currentLocation: CLLocation? = nil) throws {
        let latitude: Double
        let longitude: Double
        
        switch selection.location {
        case .named(_):
            throw OpenMeteoRequestError.unsupportedLocationType
        case .closest:
            guard let location = currentLocation else {
                throw OpenMeteoRequestError.missingLocation
            }
            
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        case .point(let pointLatitude, let pointLongitude):
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
        allTemperatures + allDewPoints + allWindSpeeds + allWindDirections + allGeopotentialHeights
    }
}
