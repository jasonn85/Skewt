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
    static let locationMiddleware: Middleware<State> = { state, action in
        guard let action = action as? LocationState.Action else {
            return Empty().eraseToAnyPublisher()
        }
        
        switch action {
        case .requestLocation:
            return LocationManager.shared.requestLocation()
        default:
            return Empty().eraseToAnyPublisher()
        }
    }
}

class LocationManager: NSObject {
    static let shared = LocationManager()
        
    private let locationManager = CLLocationManager()
    private let publisher = PassthroughSubject<Action, Never>()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func requestLocation() -> AnyPublisher<Action, Never> {
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
        locationManager.startUpdatingLocation()
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
        manager.stopUpdatingLocation()
    }
}
