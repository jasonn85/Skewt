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
}
