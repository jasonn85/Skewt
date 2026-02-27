//
//  LocationMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 5/19/23.
//

import Foundation
import Combine
import CoreLocation

extension Middlewares {
    static let locationMiddleware: Middleware<SkewtState> = { _, state, action in
        switch action as? LocationState.Action {
        case .requestLocation:
            return LocationManager.requestLocation()
        case .didDetermineLocation(_):
            if state.currentSoundingState.resolvedSounding == nil,
               state.currentSoundingState.selection.requiresLocation {
                return Just(SoundingState.Action.refreshTapped).eraseToAnyPublisher()
            }

            fallthrough
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
}

final class LocationManager: NSObject {
    private let locationManager = CLLocationManager()
    private let publisher = PassthroughSubject<Action, Never>()

    static func requestLocation() -> AnyPublisher<Action, Never> {
        let manager = LocationManager()
        
        return manager.requestLocationPublisher()
            .handleEvents(
                receiveCompletion: { [manager] _ in
                    withExtendedLifetime(manager) {}
                },
                receiveCancel: { [manager] in
                    withExtendedLifetime(manager) {}
                }
            )
            .eraseToAnyPublisher()
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    private func requestLocationPublisher() -> AnyPublisher<Action, Never> {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return requestPermission()
        case .denied, .restricted:
            return Just(LocationState.Action.permissionWasDenied).eraseToAnyPublisher()
        case .authorizedAlways, .authorizedWhenInUse:
            return getLocation()
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
    
    private func requestPermission() -> AnyPublisher<Action, Never> {
        locationManager.requestWhenInUseAuthorization()
        return publisher.eraseToAnyPublisher()
    }
    
    private func getLocation() -> AnyPublisher<Action, Never> {
        locationManager.requestLocation()
        return publisher.eraseToAnyPublisher()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            publisher.send(LocationState.Action.permissionWasDenied)
        case .authorizedAlways, .authorizedWhenInUse:
            _ = getLocation()
        default:
            return
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        publisher.send(LocationState.Action.didDetermineLocation(locations.first!))
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        publisher.send(LocationState.Action.locationRequestDidFail)
    }
}
