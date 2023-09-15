//
//  ClosestTimeTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 9/15/23.
//

import XCTest
@testable import Skewt

final class ClosestTimeTests: XCTestCase {

    func testHourRounding() {
        let exactHourComponents = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            year: 2023,
            month: 1,
            day: 1,
            hour: 12,
            minute: 0,
            second: 0,
            nanosecond: 0
        )
        var hourAfterComponents = exactHourComponents
        hourAfterComponents.hour = exactHourComponents.hour! + 1
        
        let exactHourDate = exactHourComponents.date!
        let hourAfterDate = hourAfterComponents.date!
        
        XCTAssertEqual(Date.nearestHour(withIntervalFromNow: exactHourDate.timeIntervalSinceNow), exactHourDate)
        
        var oneMinuteAfterComponents = exactHourComponents
        oneMinuteAfterComponents.minute = 1
        let oneMinuteAfterDate = oneMinuteAfterComponents.date!
        XCTAssertEqual(Date.nearestHour(withIntervalFromNow: oneMinuteAfterDate.timeIntervalSinceNow), exactHourDate)
        
        var fiftyNineMinutesComponents = exactHourComponents
        fiftyNineMinutesComponents.minute = 59
        let fiftyNineMinutesDate = fiftyNineMinutesComponents.date!
        XCTAssertEqual(Date.nearestHour(withIntervalFromNow: fiftyNineMinutesDate.timeIntervalSinceNow), hourAfterDate)
    }
    
    func testThreeHourRounding() {
        let interval = 3
        let midnightHourComponents = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            year: 2023,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            nanosecond: 0
        )
        let midnight = midnightHourComponents.date!
        
        var oneAmComponents = midnightHourComponents
        oneAmComponents.hour = 1
        let oneAm = oneAmComponents.date!
        
        var twoAmComponents = midnightHourComponents
        twoAmComponents.hour = 2
        let twoAm = twoAmComponents.date!
        
        var threeAmComponents = midnightHourComponents
        threeAmComponents.hour = 3
        let threeAm = threeAmComponents.date!
        
        var fourAmComponents = midnightHourComponents
        fourAmComponents.hour = 4
        let fourAm = fourAmComponents.date!
        
        XCTAssertEqual(Date.nearestHour(withIntervalFromNow: oneAm.timeIntervalSinceNow, hoursPerInterval: interval), midnight)
        XCTAssertEqual(Date.nearestHour(withIntervalFromNow: twoAm.timeIntervalSinceNow, hoursPerInterval: interval), threeAm)
        XCTAssertEqual(Date.nearestHour(withIntervalFromNow: fourAm.timeIntervalSinceNow, hoursPerInterval: interval), threeAm)
    }
}
