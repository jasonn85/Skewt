//
//  RucApiMiddlewareTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 6/30/23.
//

import XCTest
@testable import Skewt
import CoreLocation

extension Date {
    static var aMonthAgo: Date {
        Date(timeIntervalSinceNow: -30.0 * 24.0 * 60.0 * 60.0)
    }
}

final class RucApiMiddlewareTests: XCTestCase {
    let inactiveSoundingLocation = try! LocationList.Location("DPG  74003   40.20 -112.93 1326 Dugway Prvg Grou, UT/US")
    let activeSoundingLocation = try! LocationList.Location("NKX  72293   32.85 -117.12  128 Miramar Nas, CA/US")
    var recentSoundings: RecentSoundingsState!

    override func setUpWithError() throws {
        recentSoundings = RecentSoundingsState(status: .done(LatestSoundingList(soundings: [
            LatestSoundingList.Entry(stationId: .wmoId(activeSoundingLocation.wmoId!), timestamp: .now),
            LatestSoundingList.Entry(stationId: .wmoId(inactiveSoundingLocation.wmoId!), timestamp: .aMonthAgo)
        ]), .now))
    }

    func testSelectionForActiveSoundingLocation() throws {
        // A SoundingSelection location named after a recent sounding should return that location by name
        let location = try recentSoundings.recentSoundings!.soundingRequestLocation(
            forSelectionLocation: .named(activeSoundingLocation.name),
            currentLocation: nil
        )
        
        switch location {
        case .name(let name):
            XCTAssertEqual(name, activeSoundingLocation.name)
        case .geolocation(_, _):
            XCTFail("Sounding location should return request location by name")
        }
    }
    
    func testSelectionForInactiveSoundingLocation() throws {
        // A SoundingSelection named for a sounding location that has _not_ had a recent sounding should
        //  return the nearest _active_ sounding location by name
        let location = try recentSoundings.recentSoundings!.soundingRequestLocation(
            forSelectionLocation: .named(inactiveSoundingLocation.name),
            currentLocation: nil
        )
        
        switch location {
        case .name(let name):
            XCTAssertEqual(name, activeSoundingLocation.name)
        case .geolocation(_, _):
            XCTFail("Inactive sounding location should return closest active sounding location by name")
        }
    }
    
    func testSelectionByGeoLocation() throws {
        // A SoundingSelection with lat/long for an active sounding site should return that site by name
        let location = try recentSoundings.recentSoundings!.soundingRequestLocation(
            forSelectionLocation: .point(latitude: activeSoundingLocation.latitude,
                                         longitude: activeSoundingLocation.longitude),
            currentLocation: nil
        )
        
        switch location {
        case .name(let name):
            XCTAssertEqual(name, activeSoundingLocation.name)
        case .geolocation(_, _):
            XCTFail("Active sounding location by lat/long should return that sounding location name")
        }
    }
    
    func testSelectionByClosestLocationMissingCurrentLocation() {
        do {
            _ = try recentSoundings.recentSoundings!.soundingRequestLocation(
                forSelectionLocation: .closest,
                currentLocation: nil
            )
            
            XCTFail("Generating a request location for closest while missing current location should throw an exception")
        } catch RucRequestError.missingCurrentLocation {
            return
        } catch {
            XCTFail("Generating a request location for closest while missing current location should throw .missingCurrentLocation")
        }
    }
    
    func testSelectionByClosestLocation() throws {
        let geolocation = CLLocation(latitude: activeSoundingLocation.latitude, longitude: activeSoundingLocation.longitude)
        let location = try recentSoundings.recentSoundings!.soundingRequestLocation(forSelectionLocation: .closest, currentLocation: geolocation)
        
        switch location {
        case .name(let name):
            XCTAssertEqual(name, activeSoundingLocation.name)
        case .geolocation(_, _):
            XCTFail("Generating a request location for closest should return an active station by name")
        }
    }
}
