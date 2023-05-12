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
        XCTAssertEqual(zeroC.value(inUnit: .celsius), 0.0)
        XCTAssertEqual(bodyTempF.value(inUnit: .fahrenheit), 98.6)
        XCTAssertEqual(absoluteZeroK.value(inUnit: .kelvin), 0.0)
    }
    
    func testConversions() {
        XCTAssertEqual(bodyTempC.value(inUnit: .fahrenheit), bodyTempF.value(inUnit: .fahrenheit))
        XCTAssertEqual(absoluteZeroC.value(inUnit: .kelvin), absoluteZeroK.value(inUnit: .kelvin))
        XCTAssertEqual(Temperature.standardSeaLevel.value(inUnit: .kelvin), 288.15)
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
            XCTAssertEqual(Temperature(t).temperatureOfDryParcelRaised(from: 0.0, to: 0.0)
                .value(inUnit: .celsius),
                           t)
        }
        
        let standardTemperature = Temperature(15.0)
        let expectedTemperatureByAltitudeRange = [
            0.0...1_000.0: 12.01,
            0.0...5_000.0: 0.06,
            5_000.0...10_000.0: 0.06,
            0.0...10_000.0: -14.87,
            10_000...20_000.0: -14.87
        ]
        
        for (altitudeRange, expectedTemperature) in expectedTemperatureByAltitudeRange {
            XCTAssertEqual(standardTemperature.temperatureOfDryParcelRaised(from: altitudeRange.lowerBound,
                                                                            to: altitudeRange.upperBound)
                .value(inUnit: .celsius),
                           expectedTemperature,
                           accuracy: tolerance)
        }
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
        let feetPerKilometer = 3280.84
        
        let expectedSeaLevelMoistLapseRateByTemperature = [
            -10.0: 7.7,
             5.0: 5.9,
             15.0: 4.8,
             30.0: 3.6
        ]
        
        for (temperatureValue, expectedLapseRate) in expectedSeaLevelMoistLapseRateByTemperature {
            let temperature = Temperature(temperatureValue, unit: .celsius)
            let lapseRate = moistLapseRate(withTemperature: temperature, pressure: .standardSeaLevel)
            XCTAssertEqual(lapseRate, expectedLapseRate, accuracy: tolerance)
            XCTAssertEqual(temperature.temperatureOfSaturatedParcelRaised(from: 0.0,
                                                                          to: feetPerKilometer,
                                                                          pressure: .standardSeaLevel)
                .value(inUnit: .celsius),
                           temperatureValue - lapseRate,
                           accuracy: tolerance)
        }
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
            let mixingRatio = saturatedMixingRatio(withTemperature: Temperature(t, unit: .celsius), pressure: .standardSeaLevel)
            XCTAssertEqual(mixingRatio, mr / 1000.0, accuracy: tolerance)
        }
    }
    
    func testTemperatureFromMixingRatio() {
        let tolerance = 5.0
        
        let expectedTemperatureBySeaLevelMixingRatio = [
            0.78: -20.0,
            1.77: -10.0,
            3.77: 0.0,
            7.66: 10.0,
            14.91: 20.0,
            28.02: 30.0,
        ]
        
        for (mixingRatio, expectedTemperature) in expectedTemperatureBySeaLevelMixingRatio {
            let temperature = Temperature.temperature(forMixingRatio: mixingRatio, pressure: .standardSeaLevel)
            XCTAssertEqual(temperature.value(inUnit: .celsius),
                           expectedTemperature,
                           accuracy: tolerance)
        }
        
    }
}
