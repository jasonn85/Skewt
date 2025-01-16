//
//  SoundingWindDataTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 11/10/23.
//

import XCTest
@testable import Skewt

final class SoundingWindDataTests: XCTestCase {
    func testWindDataFiltering() throws {
        let types: [RucSounding.LevelDataPoint.DataPointType] = [.mandatoryLevel, .significantLevel, .windLevel]
        
        var data = stride(from: 0, through: 49, by: 1).map {
            RucSounding.LevelDataPoint(
                type: types[$0 % types.count],
                pressure: 1013.0 - Double($0),
                height: nil,
                temperature: nil,
                dewPoint: nil,
                windDirection: $0 * 7,
                windSpeed: $0
            )
        }
        
        let noWindPoint = RucSounding.LevelDataPoint(type: .significantLevel, pressure: 1013, height: nil, temperature: 15, dewPoint: 0, windDirection: nil, windSpeed: nil)
        
        data.insert(noWindPoint, at: 0)
        data.insert(noWindPoint, at: 25)
        data.append(noWindPoint)
        
        let sounding = try RucSounding(withJustData: data)
    
        XCTAssertEqual(sounding.data.windData.count, 50)
    }
    
    func testWindDataComponentization() {
        let accuracy = 0.01
        let magnitudes: [Int] = [0, 1, 5, 10, 25, 50, 100]
        let directions = stride(from: 0, to: 360, by: 1)
        
        magnitudes.forEach { magnitude in
            let data = directions.map { direction in
                RucSounding.LevelDataPoint(
                    type: .windLevel,
                    pressure: 1013.0 - Double(direction),
                    height: nil,
                    temperature: nil,
                    dewPoint: nil,
                    windDirection: direction,
                    windSpeed: magnitude
                )
            }
            
            let sounding = try! RucSounding(withJustData: data)
            
            XCTAssertEqual(sounding.data.windData.count, data.count)
            
            sounding.data.windDataDirectionalComponents.forEach {
                XCTAssertEqual(sqrt(pow($0.n, 2) + pow($0.e, 2)), Double(magnitude), accuracy: accuracy)
            }
        }
        
        directions.forEach { direction in
            let data = magnitudes.filter({$0 > 0}).map { magnitude in
                RucSounding.LevelDataPoint(
                    type: .windLevel,
                    pressure: 1013.0 - Double(direction),
                    height: nil,
                    temperature: nil,
                    dewPoint: nil,
                    windDirection: direction,
                    windSpeed: magnitude
                )
            }
            
            let sounding = try! RucSounding(withJustData: data)
            
            XCTAssertEqual(sounding.data.windData.count, data.count)
            
            sounding.data.windDataDirectionalComponents.forEach {
                
                var computedDirection = atan2($0.e, $0.n) / .pi * 180.0
                
                if computedDirection < 0.0 {
                    computedDirection += 360.0
                }
                
                XCTAssertEqual(
                    computedDirection,
                    Double(direction),
                    accuracy: accuracy,
                    String(format: "Wind direction of %03d created components %.1f north and %.1f east", direction, $0.n, $0.e)
                )
            }
        }
    }
}
