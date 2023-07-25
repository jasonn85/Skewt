//
//  RelativeLocationTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 7/2/23.
//

import XCTest
@testable import Skewt
import CoreLocation

final class RelativeLocationTests: XCTestCase {
    let center = CLLocation(latitude: 30.0, longitude: 30.0)
    let north = CLLocation(latitude: 40.0, longitude: 30.0)
    let south = CLLocation(latitude: 20.0, longitude: 30.0)
    let west = CLLocation(latitude: 30.0, longitude: 20.0)
    let east = CLLocation(latitude: 30.0, longitude: 40.0)
    let northeast = CLLocation(latitude: 35.0, longitude: 35.0)
    let southeast = CLLocation(latitude: 25.0, longitude: 35.0)
    let southwest = CLLocation(latitude: 25.0, longitude: 25.0)
    let northwest = CLLocation(latitude: 35.0, longitude: 25.0)
    
    func testRadiansToDegrees() {
        XCTAssertEqual(Radians(0.0).inDegrees, 0.0)
        XCTAssertEqual(Radians(Double.pi / 2.0).inDegrees, 90.0)
        XCTAssertEqual(Radians(Double.pi).inDegrees, 180.0)
        XCTAssertEqual(Radians(1.5 * Double.pi).inDegrees, 270.0)
        XCTAssertEqual(Radians(2.0 * .pi).inDegrees, 360.0)
    }
    
    func testDegreesToRadians() {
        XCTAssertEqual(Degrees(0.0).inRadians, 0.0)
        XCTAssertEqual(Degrees(90.0).inRadians, Double.pi / 2.0)
        XCTAssertEqual(Degrees(180.0).inRadians, Double.pi)
        XCTAssertEqual(Degrees(270.0).inRadians, 1.5 * Double.pi)
        XCTAssertEqual(Degrees(360.0).inRadians, 2.0 * Double.pi)
    }

    func testBearing() {
        let tolerance = 10.0  // a hefty tolerance since we're grossly oversimplifying trig here
        
        XCTAssertEqual(center.bearing(toLocation: north), 0.0, accuracy: tolerance)
        XCTAssertEqual(center.bearing(toLocation: south), 180.0, accuracy: tolerance)
        XCTAssertEqual(center.bearing(toLocation: west), 270.0, accuracy: tolerance)
        XCTAssertEqual(center.bearing(toLocation: east), 90.0, accuracy: tolerance)
        XCTAssertEqual(center.bearing(toLocation: northeast), 45.0, accuracy: tolerance)
        XCTAssertEqual(center.bearing(toLocation: southeast), 135.0, accuracy: tolerance)
        XCTAssertEqual(center.bearing(toLocation: southwest), 225.0, accuracy: tolerance)
        XCTAssertEqual(center.bearing(toLocation: northwest), 315.0, accuracy: tolerance)
    }
    
    func testExactOrdinalDirections() {
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 0.0), .north)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 90.0), .east)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 180.0), .south)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 270.0), .west)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 45.0), .northeast)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 135.0), .southeast)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 225.0), .southwest)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 315.0), .northwest)
    }
    
    func testNearMissOrdinalDirections() {
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 1.0), .north)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 359.0), .north)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 40.0), .northeast)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 50.0), .northeast)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 179.0), .south)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 181.0), .south)
    }
    
    func testOverflowedOrdinalDirections() {
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 360.0), .north)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 90.0 + 360.0), .east)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 180.0 + 360.0 + 360.0), .south)
        XCTAssertEqual(OrdinalDirection.closest(toBearing: 270.0 - 360.0 - 360.0), .west)
    }
}
