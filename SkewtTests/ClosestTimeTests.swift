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
    
    func testSoundingIntervalRounding() {
        let calendar = Calendar(identifier: .gregorian)
        let testEpoch = Date.init(timeIntervalSince1970: 1690398791)  // 26 Jul 2023 19:13:11 GMT
        let testEpochComponents = calendar.dateComponents(in: .gmt, from: testEpoch)
        
        var noonTodayComponents = testEpochComponents
        noonTodayComponents.hour = 12
        noonTodayComponents.minute = 0
        noonTodayComponents.second = 0
        let noonToday = calendar.date(from: noonTodayComponents)!
        
        var midnightTodayComponents = noonTodayComponents
        midnightTodayComponents.hour = 0
        let midnightToday = calendar.date(from: midnightTodayComponents)!
        
        var noonYesterdayComponents = noonTodayComponents
        noonYesterdayComponents.day! -= 1
        let noonYesterday = calendar.date(from: noonYesterdayComponents)!
        
        var hourBeforeMidnightTodayComponents = midnightTodayComponents
        hourBeforeMidnightTodayComponents.hour = 23
        hourBeforeMidnightTodayComponents.day! -= 1
        let hourBeforeMidnightToday = calendar.date(from: hourBeforeMidnightTodayComponents)!
        
        var hourAfterNoonYesterdayComponents = noonYesterdayComponents
        hourAfterNoonYesterdayComponents.hour = 13
        let hourAfterNoonYesterday = calendar.date(from: hourAfterNoonYesterdayComponents)!

        XCTAssertEqual(TimeInterval(0).closestSoundingTime(withCurrentDate: testEpoch),
                       noonToday,
                       "Closest sounding date from ~19 GMT is 12:00 GMT today")
        XCTAssertEqual(TimeInterval(.twentyFourHours).closestSoundingTime(withCurrentDate: testEpoch),
                       noonToday,
                       "Closest sounding for tomorrow is also 12:00 GMT today")
        XCTAssertEqual(noonYesterday.timeIntervalSince(testEpoch).closestSoundingTime(withCurrentDate: testEpoch),
                       noonYesterday,
                       "Closest sounding for noon yesterday is noon yesterday")
        XCTAssertEqual(hourBeforeMidnightToday.timeIntervalSince(testEpoch).closestSoundingTime(withCurrentDate: testEpoch),
                       midnightToday,
                       "Hour before midnight rounds to midnight")
        XCTAssertEqual(hourAfterNoonYesterday.timeIntervalSince(testEpoch).closestSoundingTime(withCurrentDate: testEpoch),
                       noonYesterday,
                       "Hour after noon rounds to noon")
    }
    
    func testArbitrarySoundingInterval() {
        let calendar = Calendar(identifier: .gregorian)
        let testEpoch = Date.init(timeIntervalSince1970: 1690398791)  // 26 Jul 2023 19:13:11 GMT
        
        var components = calendar.dateComponents(in: .gmt, from: testEpoch)
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        
        var mostRecentSixHourComponents = components
        mostRecentSixHourComponents.hour = 18
        let mostRecentSixHour = calendar.date(from: mostRecentSixHourComponents)
        
        XCTAssertEqual(
            Date.mostRecentSoundingTime(toDate: testEpoch, soundingIntervalInHours: 18),
            mostRecentSixHour,
            "Most recent six hour sounding time to 1913Z is 1800ZZ"
        )
        
        var mostRecentDailyComponents = components
        mostRecentDailyComponents.hour = 0
        let mostRecentDaily = calendar.date(from: mostRecentDailyComponents)
        
        XCTAssertEqual(
            Date.mostRecentSoundingTime(toDate: testEpoch, soundingIntervalInHours: 24),
            mostRecentDaily,
            "Most recent daily sounding time to 1913Z is 0000Z"
        )
    }
    
    func testSoundingTimeList() {
        let calendar = Calendar(identifier: .gregorian)
        let testEpoch = Date.init(timeIntervalSince1970: 1690398791)  // 26 Jul 2023 19:13:11 GMT
        let hourInterval = 12
        
        var expectedMostRecentSoundingComponents = calendar.dateComponents(in: .gmt, from: testEpoch)
        expectedMostRecentSoundingComponents.hour = 12
        expectedMostRecentSoundingComponents.minute = 0
        expectedMostRecentSoundingComponents.second = 0
        expectedMostRecentSoundingComponents.nanosecond = 0
        let expectedMostRecentSounding = calendar.date(from: expectedMostRecentSoundingComponents)
        
        XCTAssertEqual(Date.mostRecentSoundingTime(toDate: testEpoch, soundingIntervalInHours: hourInterval), expectedMostRecentSounding)
        
        let tenMostRecent = Date.mostRecentSoundingTimes(toDate: testEpoch, count: 10, soundingIntervalInHours: hourInterval)
        
        XCTAssertEqual(tenMostRecent.count, 10)
        
        for i in 1..<10 {
            let interval = tenMostRecent[i].timeIntervalSince(tenMostRecent[i-1])
            XCTAssertEqual(interval, TimeInterval(-Double(hourInterval) * 60.0 * 60.0))
        }
    }
    
    func testDateToSoundingSelectionTime() {
        let referenceDate = Date(timeIntervalSince1970: 1702412771)  // December 12, 2023 20:26:11 UTC
        
        // op40 just spits back the time interval (or .now)
        XCTAssertEqual(referenceDate.soundingSelectionTime(forModelType: .automaticForecast, referenceDate: referenceDate), .now)
        let oneHour = TimeInterval(60.0 * 60.0)
        let oneHourAgo = referenceDate.addingTimeInterval(-oneHour)
        XCTAssertEqual(oneHourAgo.soundingSelectionTime(forModelType: .automaticForecast, referenceDate: referenceDate), .relative(-oneHour))
        
        // RAOB now is most recent
        XCTAssertEqual(referenceDate.soundingSelectionTime(forModelType: .raob, referenceDate: referenceDate), .now)
        
        // RAOB minus one hour is most recent
        XCTAssertEqual(oneHourAgo.soundingSelectionTime(forModelType: .raob, referenceDate: referenceDate), .now)
        
        // RAOB 12 hours ago is most recent
        let twelveHoursAgo = referenceDate.addingTimeInterval(-12.0 * 60.0 * 60.0)
        XCTAssertEqual(twelveHoursAgo.soundingSelectionTime(forModelType: .raob, referenceDate: referenceDate), .now)
        
        // RAOB 24 hours ago is +2
        let dayAgo = referenceDate.addingTimeInterval(-24.0 * 60.0 * 60.0)
        XCTAssertEqual(dayAgo.soundingSelectionTime(forModelType: .raob, referenceDate: referenceDate), .numberOfSoundingsAgo(2))
        
        // RAOB 23/25 hours ago is +2
        let dayAgoMinusHour = referenceDate.addingTimeInterval(-23.0 * 60.0 * 60.0)
        let dayAgoPlusHour = referenceDate.addingTimeInterval(-25.0 * 60.0 * 60.0)
        XCTAssertEqual(dayAgoMinusHour.soundingSelectionTime(forModelType: .raob, referenceDate: referenceDate), .numberOfSoundingsAgo(2))
        XCTAssertEqual(dayAgoPlusHour.soundingSelectionTime(forModelType: .raob, referenceDate: referenceDate), .numberOfSoundingsAgo(2))
    }
}
