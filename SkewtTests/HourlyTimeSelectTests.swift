//
//  HourlyTimeSelectTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 9/15/23.
//

import XCTest
@testable import Skewt

final class HourlyTimeSelectTests: XCTestCase {

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
}
