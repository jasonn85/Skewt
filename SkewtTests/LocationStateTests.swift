//
//  LocationStateTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 5/30/23.
//

import XCTest
import CoreLocation
@testable import Skewt

final class LocationStateTests: XCTestCase {

    func testLocationStored() {
        let appleLatitude = 37.3346
        let appleLongitude = -122.0090
        let location = CLLocation(latitude: appleLatitude, longitude: appleLongitude)
        let initialState = LocationState(status: .requestingPermission)
        
        let state = LocationState.reducer(initialState, LocationState.Action.didDetermineLocation(location))
        
        guard case .locationKnown(latitude: let latitude, longitude: let longitude, time: _) = state.status else {
            XCTFail(".didDetermineLocation action results in .locationKnown status")
            return
        }
        
        XCTAssertEqual(latitude, appleLatitude)
        XCTAssertEqual(longitude, appleLongitude)
    }
    
    func testTimestampStored() {
        let appleLatitude = 37.3346
        let appleLongitude = -122.0090
        let expectedTimestamp = Date(timeIntervalSince1970: 1685473848.0)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: appleLatitude,
                longitude: appleLongitude
            ),
            altitude: 0.0,
            horizontalAccuracy: 100.0,
            verticalAccuracy: 100.0,
            timestamp: expectedTimestamp)
        let initialState = LocationState(status: .requestingPermission)
        
        let state = LocationState.reducer(initialState, LocationState.Action.didDetermineLocation(location))
        
        guard case .locationKnown(_, _, let timestamp) = state.status else {
            XCTFail(".didDetermineLocation action results in .locationKnown status")
            return
        }
        
        XCTAssertEqual(timestamp, expectedTimestamp)
    }
    
    func testImmediateErrorIgnored() {
        let oneSecondAgo = Date(timeIntervalSinceNow: -1.0)
        let initialState = LocationState(status: .locationKnown(latitude: 0.0, longitude: 0.0, time: oneSecondAgo))
        
        let state = LocationState.reducer(initialState, LocationState.Action.locationRequestDidFail)
        
        guard case .locationKnown(_, _, time: oneSecondAgo) = state.status else {
            XCTFail("An error one second after the location was determined should retain .locationKnown")
            return
        }
    }
    
    func testLessThanImmediateErrorsReported() {
        let anHourAgo = Date(timeIntervalSinceNow: -60.0 * 60.0)
        let fiveMinutesAgo = Date(timeIntervalSinceNow: -5.0 * 60.0)
        let statuses: [LocationState.Status] = [
            .locationKnown(latitude: 0.0, longitude: 0.0, time: anHourAgo),
            .locationKnown(latitude: 0.0, longitude: 0.0, time: fiveMinutesAgo),
            .locationRequestFailed,
            .permissionDenied,
            .requestingPermission
        ]
        
        statuses.forEach {
            let initialState = LocationState(status: $0)
            let action = LocationState.Action.locationRequestDidFail
            
            let state = LocationState.reducer(initialState, action)
                        
            guard case .locationRequestFailed = state.status else {
                XCTFail("\(action) should result in .locationRequestFailed status")
                return
            }
        }
    }
}
