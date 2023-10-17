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
        let jan1 = Date(timeIntervalSince1970: 1672560000)  // Sunday, January 1, 2023 08:00:00 GMT
        XCTAssertEqual(jan1.fractionalYearInRadians, 0.0, accuracy: 0.1)
        
        let dec31 = Date(timeIntervalSince1970: 1704009600)  // Sunday, December 31, 2023 08:00:00 GMT
        XCTAssertEqual(dec31.fractionalYearInRadians, 2.0 * .pi, accuracy: 0.1)
        
        let may7 = Date(timeIntervalSince1970: 484297200)  // Tuesday, May 7, 1985 07:00:00 GMT
        XCTAssertEqual(may7.fractionalYearInRadians, 2.18, accuracy: 0.1)
    }

    func testExactTimesNoLocationSpecified() {
        let sunriseInDenver = Date(timeIntervalSince1970: 1697465520)  // Mon, 16 Oct 2023 07:12:00 MDT
        let sunsetInDenver = Date(timeIntervalSince1970: 1697505660)  // Mon, 16 Oct 2023 18:21:00 MDT
        
        XCTAssertEqual(TimeInterval.timeToNearestSunrise(atLocation: nil, referenceDate: sunriseInDenver), 0)
        XCTAssertEqual(TimeInterval.timeToNearestSunset(atLocation: nil, referenceDate: sunsetInDenver), 0)
    }
    
    func testSanDiegoSunTimes() {
        let accuracy = TimeInterval(60.0)  // One minute
        let sanDiego = CLLocation(latitude: 32.7335, longitude: -117.1897)  // KSAN in San Diego, CA
        let sunriseInSanDiego = Date(timeIntervalSince1970: 1697464440)  // Mon, 16 Oct 2023 06:54:00 PDT
        let sunsetInSanDiego = Date(timeIntervalSince1970: 1697505360)  // Mon, 16 Oct 2023 18:16:00 PDT
        let sunsetYesterdayInSanDiego = Date(timeIntervalSince1970: 1697418900)  // Sun, 15 Oct 2023 18:15:00 PDT
        
        let noon = Date(timeIntervalSince1970: 1697482800)  // Mon, 16 Oct 2023 12:00:00 PDT
        let sunriseToNoon = noon.timeIntervalSince(sunriseInSanDiego)
        let noonToSunset = sunsetInSanDiego.timeIntervalSince(noon)
        
        XCTAssertEqual(TimeInterval.timeToNearestSunrise(atLocation: sanDiego, referenceDate: noon), -sunriseToNoon, accuracy: accuracy)
        XCTAssertEqual(TimeInterval.timeToNearestSunset(atLocation: sanDiego, referenceDate: noon), noonToSunset, accuracy: accuracy)
        
        let midnight = Date(timeIntervalSince1970: 1697439600)  // Mon, 16 Oct 2023 00:00:00 PDT
        let midnightToSunrise = sunriseInSanDiego.timeIntervalSince(midnight)
        let sunsetToMidnight = midnight.timeIntervalSince(sunsetYesterdayInSanDiego)
        
        XCTAssertEqual(TimeInterval.timeToNearestSunrise(atLocation: sanDiego, referenceDate: midnight), midnightToSunrise, accuracy: accuracy)
        XCTAssertEqual(TimeInterval.timeToNearestSunset(atLocation: sanDiego, referenceDate: midnight), midnightToSunrise, accuracy: accuracy)
    }
    
    func testPolarSeasons() {
        // TODO:
    }
}
