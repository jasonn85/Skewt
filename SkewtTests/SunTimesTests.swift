//
//  SunTimesTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 10/16/23.
//

import XCTest
@testable import Skewt
import CoreLocation

final class SunTimesTests: XCTestCase {
    
    func testFractionalYear() {
        let accuracy = 0.1
        
        let jan1 = Date(timeIntervalSince1970: 1672560000)  // Sunday, January 1, 2023 08:00:00 GMT
        XCTAssertEqual(jan1.fractionalYearInRadians, 0.0, accuracy: accuracy)
        
        let dec31 = Date(timeIntervalSince1970: 1704009600)  // Sunday, December 31, 2023 08:00:00 GMT
        XCTAssertEqual(dec31.fractionalYearInRadians, 2.0 * .pi, accuracy: accuracy)
        
        let may7 = Date(timeIntervalSince1970: 484297200)  // Tuesday, May 7, 1985 07:00:00 GMT
        XCTAssertEqual(may7.fractionalYearInRadians, 2.18, accuracy: accuracy)
    }
    
    func testSolarDeclination() {
        let accuracy = 0.01
        
        let jan17 = Date(timeIntervalSince1970: 1673942400)  // Tuesday, January 17, 2023 08:00:00 GMT
        XCTAssertEqual(jan17.solarDeclination, -21.0 * .pi / 180.0, accuracy: accuracy)
        
        let march16 = Date(timeIntervalSince1970: 1678950000)  // Thursday, March 16, 2023 07:00:00 GMT
        XCTAssertEqual(march16.solarDeclination, -2.4 * .pi / 180.0, accuracy: accuracy)

        let july17 = Date(timeIntervalSince1970: 1689577200)  // Monday, July 17, 2023 07:00:00 GMT
        XCTAssertEqual(july17.solarDeclination, 21.2 * .pi / 180.0, accuracy: accuracy)
    }
    
    func testEquationOfTime() {
        let accuracy: TimeInterval = 60.0
        
        let feb11 = Date(timeIntervalSince1970: 950256000)  // Monday, July 17, 2023 07:00:00 GMT
        XCTAssertEqual(feb11.equationOfTime, -14.0 * 60.0 - 15.0, accuracy: accuracy)
        
        let jun13 = Date(timeIntervalSince1970: 960879600)  // Tuesday, June 13, 2000 07:00:00 GMT
        XCTAssertEqual(jun13.equationOfTime, 0.0, accuracy: accuracy)
        
        let nov3 = Date(timeIntervalSince1970: 973238400)  // Friday, November 3, 2000 08:00:00 GMT
        XCTAssertEqual(nov3.equationOfTime, 16.0 * 60.0 + 25.0, accuracy: accuracy)
        
        let dec25 = Date(timeIntervalSince1970: 977731200)  // Monday, December 25, 2000 08:00:00 GMT
        XCTAssertEqual(dec25.equationOfTime, 0.0, accuracy: accuracy)
    }

    func testExactTimesNoLocationSpecified() {
        let accuracy = TimeInterval(5.0 * 60.0)  // Five minutes

        let sunriseInDenver = Date(timeIntervalSince1970: 1697461800)  // Monday, October 16, 2023 13:10:00 GMT
        let sunsetInDenver = Date(timeIntervalSince1970: 1697501880)  // Tuesday, October 17, 2023 12:18:00 GMT
        
        XCTAssertEqual(TimeInterval.timeToNearestSunrise(atLocation: nil, referenceDate: sunriseInDenver)!, 0, accuracy: accuracy)
        XCTAssertEqual(TimeInterval.timeToNearestSunset(atLocation: nil, referenceDate: sunsetInDenver)!, 0, accuracy: accuracy)
    }
    
    func testExactTimesSpecificLocations() {
        let accuracy = TimeInterval(5.0 * 60.0)  // Five minutes

        let locationSunriseAndSunset = [
            (
                CLLocation(latitude: 3.16, longitude: 101.71),
                Date(timeIntervalSince1970: 1697583420),
                Date(timeIntervalSince1970: 1697626740)
            ),  // Kuala Lumpur
            (
                CLLocation(latitude: -33.93, longitude: 18.46),
                Date(timeIntervalSince1970: 1697515320),
                Date(timeIntervalSince1970: 1697562060)
            ),  // Cape Town
            (
                CLLocation(latitude: 35.67, longitude: 139.8),
                Date(timeIntervalSince1970: 1697575740),
                Date(timeIntervalSince1970: 1697616120)
            )  // Tokyo
        ]
        
        locationSunriseAndSunset.forEach {
            XCTAssertEqual(TimeInterval.timeToNearestSunrise(atLocation: $0.0, referenceDate: $0.1)!, 0.0, accuracy: accuracy)
            XCTAssertEqual(TimeInterval.timeToNearestSunset(atLocation: $0.0, referenceDate: $0.2)!, 0.0, accuracy: accuracy)
        }
    }
    
    func testSanDiegoSunTimes() {
        let accuracy = TimeInterval(5.0 * 60.0)  // Five minutes
        let sanDiego = CLLocation(latitude: 32.7335, longitude: -117.1897)  // KSAN in San Diego, CA
        let sunriseInSanDiego = Date(timeIntervalSince1970: 1697464440)  // Mon, 16 Oct 2023 06:54:00 PDT
        let sunsetInSanDiego = Date(timeIntervalSince1970: 1697505360)  // Mon, 16 Oct 2023 18:16:00 PDT
        let sunsetYesterdayInSanDiego = Date(timeIntervalSince1970: 1697418900)  // Sun, 15 Oct 2023 18:15:00 PDT
        
        let noon = Date(timeIntervalSince1970: 1697482800)  // Mon, 16 Oct 2023 12:00:00 PDT
        let sunriseToNoon = noon.timeIntervalSince(sunriseInSanDiego)
        let noonToSunset = sunsetInSanDiego.timeIntervalSince(noon)
        
        XCTAssertFalse(sunriseInSanDiego.addingTimeInterval(-60.0 * 60.0).isDaylight(at: sanDiego))
        XCTAssertTrue(sunriseInSanDiego.addingTimeInterval(60.0 * 60.0).isDaylight(at: sanDiego))
        XCTAssertTrue(noon.isDaylight(at: sanDiego))
        XCTAssertTrue(sunsetInSanDiego.addingTimeInterval(-60.0 * 60.0).isDaylight(at: sanDiego))
        XCTAssertFalse(sunsetInSanDiego.addingTimeInterval(60.0 * 60.0).isDaylight(at: sanDiego))
        
        XCTAssertEqual(TimeInterval.timeToNearestSunrise(atLocation: sanDiego, referenceDate: noon)!, -sunriseToNoon, accuracy: accuracy)
        XCTAssertEqual(TimeInterval.timeToNearestSunset(atLocation: sanDiego, referenceDate: noon)!, noonToSunset, accuracy: accuracy)
        
        let midnight = Date(timeIntervalSince1970: 1697439600)  // Mon, 16 Oct 2023 00:00:00 PDT
        let midnightToSunrise = sunriseInSanDiego.timeIntervalSince(midnight)
        let sunsetToMidnight = midnight.timeIntervalSince(sunsetYesterdayInSanDiego)
        
        XCTAssertEqual(TimeInterval.timeToNearestSunrise(atLocation: sanDiego, referenceDate: midnight)!, midnightToSunrise, accuracy: accuracy)
        XCTAssertEqual(TimeInterval.timeToNearestSunset(atLocation: sanDiego, referenceDate: midnight)!, -sunsetToMidnight, accuracy: accuracy)
    }
    
    func testPolarSeasons() {
        let southPole = CLLocation(latitude: -90.0, longitude: 0.0)
        let mcmurdo = CLLocation(latitude: -77.85, longitude: 166.6)
        let northPole = CLLocation(latitude: 90.0, longitude: 0.0)
        let twoWeeks = TimeInterval(14.0 * 24.0 * 60.0 * 60.0)
        let southPoleNightDate = Date(timeIntervalSince1970: 1686691830)  // Tuesday, June 13, 2023 21:30:30 GMT
        let southPoleDayDate = Date(timeIntervalSince1970: 1703799030)  //  Thursday, December 28, 2023 21:30:30 GMT
        
        XCTAssertNil(Date.sunrise(at: southPole, onDate: southPoleNightDate))
        XCTAssertFalse(southPoleNightDate.isDaylight(at: southPole))
        XCTAssertNil(Date.sunset(at: southPole, onDate: southPoleDayDate))
        XCTAssertTrue(southPoleDayDate.isDaylight(at: southPole))
        XCTAssertNil(Date.sunrise(at: northPole, onDate: southPoleNightDate))
        XCTAssertTrue(southPoleNightDate.isDaylight(at: northPole))
        XCTAssertNil(Date.sunset(at: northPole, onDate: southPoleDayDate))
        XCTAssertFalse(southPoleDayDate.isDaylight(at: northPole))
        
        // We just ensure that near polar sunrise/sunsets are at least two weeks away rather than expecting any
        //  sort of precision.
        let lastSunrise = Date.priorSunriseOrSunset(sunrise: true, at: mcmurdo, toDate: southPoleNightDate)
        let nextSunrise = Date.nextSunriseOrSunset(sunrise: true, at: mcmurdo, afterDate: southPoleNightDate)
        XCTAssertNotNil(lastSunrise)
        XCTAssertNotNil(nextSunrise)
        XCTAssertTrue(southPoleNightDate.timeIntervalSince(lastSunrise!) > twoWeeks)
        XCTAssertTrue(nextSunrise!.timeIntervalSince(southPoleNightDate) > twoWeeks)
        
        // We don't care about return value for sunrise/sunset exactly at the pole, but we will
        //  check that it does not cause an infinite loop
        _ = Date.priorSunriseOrSunset(sunrise: true, at: southPole, toDate: southPoleNightDate)
        _ = Date.nextSunriseOrSunset(sunrise: true, at: southPole, afterDate: southPoleNightDate)
        _ = Date.priorSunriseOrSunset(sunrise: true, at: northPole, toDate: southPoleNightDate)
        _ = Date.nextSunriseOrSunset(sunrise: true, at: northPole, afterDate: southPoleNightDate)
    }
}
