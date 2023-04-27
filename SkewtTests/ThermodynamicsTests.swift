//
//  ThermodynamicsTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 3/10/23.
//

import XCTest
@testable import Skewt

final class ThermodynamicsTests: XCTestCase {
    private let zeroC = Temperature(0.0, unit: .celsius)
    private let zeroF = Temperature(0.0, unit: .fahrenheit)
    private let bodyTempC = Temperature(37.0, unit: .celsius)
    private let bodyTempF = Temperature(98.6, unit: .fahrenheit)
    private let absoluteZeroK = Temperature(0.0, unit: .kelvin)
    private let absoluteZeroC = Temperature(-273.15, unit: .celsius)
    
    func testIdentityConversions() {
        XCTAssertEqual(zeroC.inUnit(.celsius).value, zeroC.value)
        XCTAssertEqual(bodyTempF.inUnit(.fahrenheit).value, bodyTempF.value)
        XCTAssertEqual(absoluteZeroK.inUnit(.kelvin).value, absoluteZeroK.value)
    }
    
    func testConversions() {
        XCTAssertEqual(bodyTempC.inUnit(.fahrenheit).value, bodyTempF.value)
        XCTAssertEqual(absoluteZeroC.inUnit(.kelvin).value, absoluteZeroK.value)
        XCTAssertEqual(Temperature.standardSeaLevel.inUnit(.kelvin).value, 288.15)
    }
    
    func testCrossUnitEquality() {
        XCTAssertEqual(bodyTempC, bodyTempF)
        XCTAssertEqual(absoluteZeroC, absoluteZeroK)
        XCTAssertNotEqual(zeroC, zeroF)
    }
    
    func testComparing() {
        XCTAssertTrue(zeroC < bodyTempC)
        XCTAssertTrue(zeroC < bodyTempF)
        XCTAssertTrue(bodyTempF > zeroC)
        XCTAssertTrue(zeroC > absoluteZeroK)
        XCTAssertTrue(zeroF < zeroC)
    }
    
    func testStandardPressure() {
        let pressureTolerace = 1.0
        XCTAssertEqual(Pressure.standardPressure(atAltitude: 0.0), Pressure.standardSeaLevel, accuracy: pressureTolerace)
        XCTAssertEqual(Pressure.standardPressure(atAltitude: 5_000), 843.2108, accuracy: pressureTolerace)
        XCTAssertEqual(Pressure.standardPressure(atAltitude: 10_000), 697.5961, accuracy: pressureTolerace)
        XCTAssertEqual(Pressure.standardPressure(atAltitude: 36_089), 226.3206, accuracy: pressureTolerace)
        
        let altitudeTolerance = 50.0
        XCTAssertEqual(Altitude.standardAltitude(forPressure: Pressure.standardSeaLevel), 50.0, accuracy: altitudeTolerance)
        XCTAssertEqual(Altitude.standardAltitude(forPressure: 843.2108), 5_000, accuracy: altitudeTolerance)
        XCTAssertEqual(Altitude.standardAltitude(forPressure: 697.5961), 10_000, accuracy: altitudeTolerance)
        XCTAssertEqual(Altitude.standardAltitude(forPressure: 226.3206), 36_089, accuracy: altitudeTolerance)
    }
    
    func testDryAdiabaticLapse() {
        let tolerance = 0.1
        
        // Identity
        for t in [-30.0, -15.0, 0.0, 15.0, 50.0] {
            XCTAssertEqual(Temperature(t).raiseDryParcel(from: 0.0, to: 0.0).value, t)
        }
        
        let standardTemperature = Temperature(15.0)
        XCTAssertEqual(standardTemperature.raiseDryParcel(from: 0.0, to: 1_000.0).value, 12.01, accuracy: tolerance)
        XCTAssertEqual(standardTemperature.raiseDryParcel(from: 0.0, to: 5_000.0).value, 0.06, accuracy: tolerance)
        XCTAssertEqual(standardTemperature.raiseDryParcel(from: 5_000.0, to: 10_000.0).value, 0.06, accuracy: tolerance)
        XCTAssertEqual(standardTemperature.raiseDryParcel(from: 0.0, to: 10_000.0).value, -14.87, accuracy: tolerance)
        XCTAssertEqual(standardTemperature.raiseDryParcel(from: 10_000.0, to: 20_000.0).value, -14.87, accuracy: tolerance)
    }
}
