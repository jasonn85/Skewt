//
//  SoundingTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 10/30/24.
//

import XCTest
@testable import Skewt

final class SoundingTests: XCTestCase {
    func testNearestValue() throws {
        let temperaturesAndPressures = [(-20.0, 1000.0), (-10.0, 900.0), (0.0, 800.0), (10.0, 700.0), (20.0, 600.0)]
        let dewPointSpread = 10.0
        
        let points = temperaturesAndPressures.map {
            RucSounding.LevelDataPoint(
                type: .significantLevel,
                pressure: $0.1,
                height: nil,
                temperature: $0.0,
                dewPoint: $0.0 - dewPointSpread,
                windDirection: nil,
                windSpeed: nil
            )
        }
        
        let sounding = try RucSounding(withJustData: Array(points))

        XCTAssertEqual(
            sounding.data.closestValue(toPressure: temperaturesAndPressures[0].1, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures[0].0,
            "Closest value to first value is first value"
        )
        
        XCTAssertEqual(
            sounding.data.closestValue(toPressure: 1500.0, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures[0].0,
            "Closest value to underground is first value"
        )
        
        XCTAssertEqual(
            sounding.data.closestValue(toPressure: temperaturesAndPressures.last!.1, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures.last!.0,
            "Closest value to last value is last value"
        )
        
        XCTAssertEqual(
            sounding.data.closestValue(toPressure: 0.0, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures.last!.0,
            "Closest value to space is last value"
        )
        
        let closerToTwoThanThreePressure = (temperaturesAndPressures[2].1
                                            + temperaturesAndPressures[2].1
                                            + temperaturesAndPressures[3].1) / 3.0
        XCTAssertEqual(
            sounding.data.closestValue(toPressure: closerToTwoThanThreePressure, withValueFor: \.temperature)!.temperature,
            temperaturesAndPressures[2].0,
            "A pressure closer to entry #2 than #3 results in #2"
        )
    }
    
    func testInterpolation() throws {
        let temperaturesAndPressures = [(-20.0, 1000.0), (-10.0, 900.0), (0.0, 800.0), (10.0, 700.0), (20.0, 600.0)]
        let dewPointSpread = 10.0
        
        let points = temperaturesAndPressures.map {
            RucSounding.LevelDataPoint(
                type: .significantLevel,
                pressure: $0.1,
                height: nil,
                temperature: $0.0,
                dewPoint: $0.0 - dewPointSpread,
                windDirection: nil,
                windSpeed: nil
            )
        }
    
        let sounding = try RucSounding(withJustData: Array(points))
        
        XCTAssertEqual(
            sounding.data.interpolatedValue(for: \.temperature, atPressure: temperaturesAndPressures[0].1),
            points[0].temperature,
            "Interpolation returns exact match if one exists"
        )
        XCTAssertEqual(
            sounding.data.interpolatedValue(for: \.temperature, atPressure: temperaturesAndPressures[4].1),
            points[4].temperature,
            "Interpolation returns exact match if one exists"
        )
        XCTAssertEqual(
            sounding.data.interpolatedValue(for: \.dewPoint, atPressure: temperaturesAndPressures[0].1),
            points[0].dewPoint,
            "Interpolation returns exact match if one exists"
        )
        
        let hopefullyFive = sounding.data.interpolatedValue(
            for: \.temperature,
            atPressure: (temperaturesAndPressures[2].1 + temperaturesAndPressures[3].1) / 2.0
        )
        XCTAssertNotNil(hopefullyFive)
        XCTAssertTrue(hopefullyFive! > temperaturesAndPressures[2].0)
        XCTAssertTrue(hopefullyFive! < temperaturesAndPressures[3].0)
        
        let hopefullyNegativeFifteen = sounding.data.interpolatedValue(
            for: \.temperature,
            atPressure: (temperaturesAndPressures[0].1 + temperaturesAndPressures[1].1) / 2.0
        )
        XCTAssertNotNil(hopefullyNegativeFifteen)
        XCTAssertTrue(hopefullyNegativeFifteen! > temperaturesAndPressures[0].0)
        XCTAssertTrue(hopefullyNegativeFifteen! < temperaturesAndPressures[1].0)
    }
}
