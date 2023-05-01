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
    
    func testWaterVaporPressure() {
        let tolerance = 10.0
        
        XCTAssertEqual(Temperature(-20.0).saturatedVaporPressure, 125.4, accuracy: tolerance)
        XCTAssertEqual(Temperature(0.0).saturatedVaporPressure, 610.7, accuracy: tolerance)
        XCTAssertEqual(Temperature(15.0).saturatedVaporPressure, 1_704.0, accuracy: tolerance)
        XCTAssertEqual(Temperature(40.0).saturatedVaporPressure, 7_377.0, accuracy: tolerance)
    }
    
    func testMoistAdiabaticLapse() {
        let tolerance = 0.2
        let seaLevel = Pressure.standardSeaLevel
        let feetPerKilometer = 3280.84
        
        let pm10 = AirParcel(temperature: Temperature(-10.0), pressure: seaLevel)
        XCTAssertEqual(pm10.moistLapseRate, 7.7, accuracy: tolerance)
        XCTAssertEqual(pm10.raiseParcel(from: 0.0, to: feetPerKilometer).value, -17.7, accuracy: tolerance)
        let p5 = AirParcel(temperature: Temperature(5.0), pressure: seaLevel)
        XCTAssertEqual(p5.moistLapseRate, 5.9, accuracy: tolerance)
        XCTAssertEqual(p5.raiseParcel(from: 0.0, to: feetPerKilometer).value, -0.9, accuracy: tolerance)
        let p15 = AirParcel(temperature: Temperature(15.0), pressure: seaLevel)
        XCTAssertEqual(p15.moistLapseRate, 4.8, accuracy: tolerance)
        XCTAssertEqual(p15.raiseParcel(from: 0.0, to: feetPerKilometer).value, 10.2, accuracy: tolerance)
        let p30 = AirParcel(temperature: Temperature(30.0), pressure: seaLevel)
        XCTAssertEqual(p30.moistLapseRate, 3.6, accuracy: tolerance)
        XCTAssertEqual(p30.raiseParcel(from: 0.0, to: feetPerKilometer).value, 26.4, accuracy: tolerance)
    }
    
    func testSeaLevelSaturatedMixingRatio() {
        let tolerance = 0.01
        
        let expectedMixingRatioBySeaLevelTemperatureC = [
            -20.0: 0.78,
             -10.0: 1.77,
             0.0: 3.77,
             10.0: 7.66,
             20.0: 14.91,
             30.0: 28.02,
             40.0: 51.43,
             50.0: 93.42,
        ]
        
        for (t, mr) in expectedMixingRatioBySeaLevelTemperatureC {
            let parcel = AirParcel(temperature: Temperature(t, unit: .celsius), pressure: .standardSeaLevel)
            XCTAssertEqual(parcel.saturatedMixingRatio, mr / 1000.0, accuracy: tolerance)
        }
    }
}
