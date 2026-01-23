//
//  SunTimesTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 10/16/23.
//

import XCTest
@testable import Skewt
import CoreLocation

struct Location {
    let location: CLLocation
    let name: String
    let gmtOffset: Int?

    let sunrises: [Date]?
    let sunsets: [Date]?
    let solarNoons: [Date]?
}

final class SunTimesTests: XCTestCase {
    var denver: Location!
    var greenwich: Location!
    var sanDiego: Location!
    var kualaLumpur: Location!
    var capeTown: Location!
    var tokyo: Location!
    var southPole: Location!
    var northPole: Location!
    var mcmurdo: Location!
    
    var locations: [Location]!
    
    override func setUp() {
        // Source to calculate sunrise/sunset/noon times: https://gml.noaa.gov/grad/solcalc/
        
        denver = Location(
            location: CLLocation(latitude: 39.87, longitude: -104.67),
            name: "Denver",
            gmtOffset: -7,
            sunrises: [
                Date(timeIntervalSince1970: 1697461800)  // Monday, October 16, 2023 13:10:00 GMT
            ],
            sunsets: [
                Date(timeIntervalSince1970: 1697501880)  // Tuesday, October 17, 2023 00:18:00 GMT
            ],
            solarNoons: [
                Date(timeIntervalSince1970: 484340113)  //  Tuesday, May 7, 1985 18:55:13 GMT
            ]
        )
        
        greenwich = Location(
            location: CLLocation(latitude: 51.47783, longitude: -0.00139),
            name: "Greenwich",
            gmtOffset: 0,
            sunrises: [
                Date(timeIntervalSince1970: 1651897260),  // Saturday, May 7, 2022 04:21:00 GMT
                Date(timeIntervalSince1970: 1672560360)  // Sunday, January 1, 2023 08:06:00 GMT
            ],
            sunsets: [
                Date(timeIntervalSince1970: 1651951980),  // Saturday, May 7, 2022 19:33:00 GMT
                Date(timeIntervalSince1970: 1672588860)  // Sunday, January 1, 2023 16:01:00 GMT
            ],
            solarNoons: [
                Date(timeIntervalSince1970: 1651924596),  // Saturday, May 7, 2022 11:56:36 AM
                Date(timeIntervalSince1970: 1672574640)  // Sunday, January 1, 2023 12:04:00 GMT
            ]
        )
        
        kualaLumpur = Location(
            location: CLLocation(latitude: 3.16, longitude: 101.71),
            name: "Kuala Lumpur",
            gmtOffset: nil,
            sunrises: [
                Date(timeIntervalSince1970: 1697583420)  // Tuesday, October 17, 2023 22:57:00 GMT
            ],
            sunsets: [
                Date(timeIntervalSince1970: 1697626740)  // Wednesday, October 18, 2023 10:59:00 GMT
            ],
            solarNoons: nil
        )
        
        capeTown = Location(
            location: CLLocation(latitude: -33.93, longitude: 18.46),
            name: "Cape Town",
            gmtOffset: 2,
            sunrises: [
                Date(timeIntervalSince1970: 1697515380)  //  Tuesday, October 17, 2023 04:03:00 GMT
            ],
            sunsets: [
                Date(timeIntervalSince1970: 1697562060)  // Tuesday, October 17, 2023 17:01:00 GMT
            ],
            solarNoons: nil
        )
        
        tokyo = Location(
            location: CLLocation(latitude: 35.67, longitude: 139.8),
            name: "Tokyo",
            gmtOffset: 9,
            sunrises: [
                Date(timeIntervalSince1970: 1697575740)  // Tuesday, October 17, 2023 20:49:00 GMT
            ],
            sunsets: [
                Date(timeIntervalSince1970: 1697616120)  // Wednesday, October 18, 2023 8:02:00 AM
            ],
            solarNoons: [
                Date(timeIntervalSince1970: 1577933051)  // Thursday, January 2, 2020 02:44:11 GMT
            ]
        )
        
        sanDiego = Location(
            location: CLLocation(latitude: 32.7335, longitude: -117.1897),
            name: "San Diego",
            gmtOffset: -8,
            sunrises: [
                Date(timeIntervalSince1970: 1697464440)  // Mon, 16 Oct 2023 06:54:00 PDT
            ],
            sunsets: [
                Date(timeIntervalSince1970: 1697505360),  // Mon, 16 Oct 2023 18:16:00 PDT
                Date(timeIntervalSince1970: 1697418900)  // Sun, 15 Oct 2023 18:15:00 PDT
            ],
            solarNoons: [
                Date(timeIntervalSince1970: 1683488721),  // Sunday, May 7, 2023 19:45:21 GMT
                Date(timeIntervalSince1970: 1577908320)  // Wednesday, January 1, 2020 19:52:00 GMT
            ]
        )
        
        southPole = Location(
            location: CLLocation(latitude: -90.0, longitude: 0.0),
            name: "South Pole",
            gmtOffset: nil,
            sunrises: nil,
            sunsets: nil,
            solarNoons: nil
        )
        
        mcmurdo = Location(
            location: CLLocation(latitude: -77.85, longitude: 166.6),
            name: "McMurdo Station",
            gmtOffset: nil,
            sunrises: nil,
            sunsets: nil,
            solarNoons: nil
        )
        
        northPole = Location(
            location: CLLocation(latitude: 90.0, longitude: 0.0),
            name: "North Pole",
            gmtOffset: nil,
            sunrises: nil,
            sunsets: nil,
            solarNoons: nil
        )
        
        locations = [
            denver,
            greenwich,
            kualaLumpur,
            capeTown,
            tokyo,
            sanDiego,
            southPole,
            mcmurdo,
            northPole
        ]
    }
    
    func testJulianDate() {
        let tolerance = 1.0
        
        let j2000 = Date(timeIntervalSince1970: 946728000)  // 2000-01-01 12:00:00 UTC
        XCTAssertEqual(j2000.julianDate, 2451545, accuracy: tolerance)
        
        let date = Date(timeIntervalSince1970: 1769150400)  // Friday, January 23, 2026 6:40:00 AM GMT
        XCTAssertEqual(date.julianDate, 2461063, accuracy: tolerance)
    }
    
    func testSiderealTime() {
        let tolerance = 0.01
        
        let date = Date(timeIntervalSince1970: 946728000) // 2000-01-01 12:00:00 UTC
        let expectedGreenwichSiderealTime = 160.46061837 * .pi / 180.0
        XCTAssertEqual(date.localSiderealTime(at: greenwich.location), expectedGreenwichSiderealTime, accuracy: tolerance)
        
        let oppositeGreenwich = CLLocation(
            latitude: -greenwich.location.coordinate.latitude,
            longitude: greenwich.location.coordinate.longitude + 180.0
        )
        XCTAssertEqual(date.localSiderealTime(at: oppositeGreenwich), expectedGreenwichSiderealTime + .pi, accuracy: tolerance)
    }
    
    func testSiderealDriftPerDay() {
        let tolerance = 0.01
        
        let location = CLLocation(latitude: 0, longitude: 0)
        
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let t1 = t0.addingTimeInterval(86400) // +1 solar day

        let s0 = t0.localSiderealTime(at: location)
        let s1 = t1.localSiderealTime(at: location)

        let delta = (s1 - s0).truncatingRemainder(dividingBy: 2 * .pi)
        let expected = 1.0 * .pi / 180.0

        XCTAssertEqual(delta, expected, accuracy: tolerance)
    }
    
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
    
    func testEquatorialLocationEstimate() {
        let longitudeAccuracy = 15.0
        
        locations.filter({ $0.gmtOffset != nil }).forEach {
            let timeZone = TimeZone(secondsFromGMT: $0.gmtOffset! * 3_600)!
            
            XCTAssertEqual(
                CLLocation.equatorialLocation(inTimeZone: timeZone).coordinate.longitude,
                $0.location.coordinate.longitude,
                accuracy: longitudeAccuracy,
                "\($0.name) GMT \($0.gmtOffset! >= 0 ? "+" : "-") \($0.gmtOffset!) estimated longitude is ~\($0.location.coordinate.longitude)"
            )
        }
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
    
    func testGmtSunTimes() {
        let angleAccuracy = 5.0 * .pi / 180.0  // 5°

        greenwich.sunrises?.forEach { sunrise in
            let hourBeforeSunrise = sunrise.addingTimeInterval(-60.0 * 60.0)
            let hourAfterSunrise = sunrise.addingTimeInterval(60.0 * 60.0)
            
            XCTAssertFalse(hourBeforeSunrise.isDaylight(at: greenwich.location))
            XCTAssertTrue(hourAfterSunrise.isDaylight(at: greenwich.location))
            XCTAssertEqual(sunrise.solarZenithAngle(at: greenwich.location), Double.sunriseZenith, accuracy: angleAccuracy)
        }
        
        greenwich.sunsets?.forEach { sunset in
            let hourBeforeSunset = sunset.addingTimeInterval(-60.0 * 60.0)
            let hourAfterSunset = sunset.addingTimeInterval(60.0 * 60.0)
            
            XCTAssertTrue(hourBeforeSunset.isDaylight(at: greenwich.location))
            XCTAssertFalse(hourAfterSunset.isDaylight(at: greenwich.location))
            XCTAssertEqual(sunset.solarZenithAngle(at: greenwich.location), Double.sunriseZenith, accuracy: angleAccuracy)
        }
        
        greenwich.solarNoons?.forEach { noon in
            XCTAssertTrue(noon.isDaylight(at: greenwich.location))
        }
        
    }
    
    func testExactTimesSpecificLocations() {
        let accuracy = TimeInterval(5.0 * 60.0)  // Five minutes
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm 'GMT'"
        
        locations.forEach { location in
            location.sunrises?.forEach { sunriseTime in
                XCTAssertEqual(
                    Date.sunrise(at: location.location, onDate: sunriseTime)!.timeIntervalSince(sunriseTime),
                    0.0,
                    accuracy: accuracy,
                    "Sunrise on \(dateFormatter.string(from: sunriseTime)) at \(location.name) is \(timeFormatter.string(from: sunriseTime))"
                )
            }
            
            location.sunsets?.forEach { sunsetTime in
                XCTAssertEqual(
                    Date.sunset(at: location.location, onDate: sunsetTime)!.timeIntervalSince(sunsetTime),
                    0.0,
                    accuracy: accuracy,
                    "Sunset on \(dateFormatter.string(from: sunsetTime)) at \(location.name) is \(timeFormatter.string(from: sunsetTime))"
                )
            }
        }
    }
    
    func testSunAngleAtDifferentLocations() {
        let accuracy = 5.0 * .pi / 180.0  // 5°
        
        locations.forEach { location in
            location.solarNoons?.forEach { solarNoon in
                XCTAssertTrue(
                    solarNoon.isDaylight(at: location.location),
                    "isDaylight on \(solarNoon) at \(location.name)"
                )
            }
        }
        
        let nonPolarLocations = locations.filter { abs($0.location.coordinate.latitude) > 33.0 }
        
        nonPolarLocations.forEach { location in
            location.solarNoons?.forEach { solarNoon in
                let nightTime = solarNoon.addingTimeInterval(12.0 * 60.0 * 60.0)  // 12 hours after solar noon
                
                XCTAssertFalse(
                    nightTime.isDaylight(at: location.location),
                    "isDaylight is false on \(nightTime) at \(location)"
                )
            }
        }
        
        locations.forEach { location in
            location.sunrises?.forEach { sunrise in
                XCTAssertEqual(
                    sunrise.solarZenithAngle(at: location.location),
                    Double.sunriseZenith,
                    accuracy: accuracy,
                    "Solar angle is ~-90° on \(sunrise) at \(location.name)"
                )
            }
            
            location.sunsets?.forEach { sunset in
                XCTAssertEqual(
                    sunset.solarZenithAngle(at: location.location),
                    Double.sunriseZenith,
                    accuracy: accuracy,
                    "Solar angle is ~-90° on \(sunset) at \(location.name)"
                )
            }
        }
    }
    
    func testSanDiegoDaylight() {
        XCTAssertFalse(sanDiego.sunrises![0].addingTimeInterval(-60.0 * 60.0).isDaylight(at: sanDiego.location))
        XCTAssertTrue(sanDiego.sunrises![0].addingTimeInterval(60.0 * 60.0).isDaylight(at: sanDiego.location))
        XCTAssertTrue(sanDiego.solarNoons![0].isDaylight(at: sanDiego.location))
        XCTAssertTrue(sanDiego.sunsets![0].addingTimeInterval(-60.0 * 60.0).isDaylight(at: sanDiego.location))
        XCTAssertFalse(sanDiego.sunsets![0].addingTimeInterval(60.0 * 60.0).isDaylight(at: sanDiego.location))
    }
    
    func testPolarSeasons() {
        let twoWeeks = TimeInterval(14.0 * 24.0 * 60.0 * 60.0)
        let southPoleNightDate = Date(timeIntervalSince1970: 1686691830)  // Tuesday, June 13, 2023 21:30:30 GMT
        let southPoleDayDate = Date(timeIntervalSince1970: 1703799030)  //  Thursday, December 28, 2023 21:30:30 GMT
        
        XCTAssertNil(Date.sunrise(at: southPole.location, onDate: southPoleNightDate))
        XCTAssertFalse(southPoleNightDate.isDaylight(at: southPole.location))
        XCTAssertNil(Date.sunset(at: southPole.location, onDate: southPoleDayDate))
        XCTAssertTrue(southPoleDayDate.isDaylight(at: southPole.location))
        XCTAssertNil(Date.sunrise(at: northPole.location, onDate: southPoleNightDate))
        XCTAssertTrue(southPoleNightDate.isDaylight(at: northPole.location))
        XCTAssertNil(Date.sunset(at: northPole.location, onDate: southPoleDayDate))
        XCTAssertFalse(southPoleDayDate.isDaylight(at: northPole.location))
        
        // We just ensure that near polar sunrise/sunsets are at least two weeks away rather than expecting any
        //  sort of precision.
        let lastSunrise = Date.priorSunriseOrSunset(sunrise: true, at: mcmurdo.location, toDate: southPoleNightDate)
        let nextSunrise = Date.nextSunriseOrSunset(sunrise: true, at: mcmurdo.location, afterDate: southPoleNightDate)
        XCTAssertNotNil(lastSunrise)
        XCTAssertNotNil(nextSunrise)
        XCTAssertTrue(southPoleNightDate.timeIntervalSince(lastSunrise!) > twoWeeks)
        XCTAssertTrue(nextSunrise!.timeIntervalSince(southPoleNightDate) > twoWeeks)
        
        // We don't care about return value for sunrise/sunset exactly at the pole, but we will
        //  check that it does not cause an infinite loop
        _ = Date.priorSunriseOrSunset(sunrise: true, at: southPole.location, toDate: southPoleNightDate)
        _ = Date.nextSunriseOrSunset(sunrise: true, at: southPole.location, afterDate: southPoleNightDate)
        _ = Date.priorSunriseOrSunset(sunrise: true, at: northPole.location, toDate: southPoleNightDate)
        _ = Date.nextSunriseOrSunset(sunrise: true, at: northPole.location, afterDate: southPoleNightDate)
    }
    
    func testSunStatesAroundMidnight() {
        let date = Date(timeIntervalSince1970: 1698390000)  // Friday, October 27, 2023 07:00:00 GMT
        let tomorrow = date.addingTimeInterval(24.0 * 60.0 * 60.0)
        let sunrise = Date.nextSunriseOrSunset(sunrise: true, at: sanDiego.location, afterDate: date)
        let sunset = Date.nextSunriseOrSunset(sunrise: false, at: sanDiego.location, afterDate: date)
        
        let sunStates = SunState.states(inRange: date...tomorrow, at: sanDiego.location)
        
        XCTAssertEqual(sunStates[0].date, date, "SunStates in range starts with starting date")
        XCTAssertEqual(sunStates[0].type, .night, "SunStates in range starting at midnight begins with night")
        
        XCTAssertEqual(sunStates[1].date, sunrise)
        XCTAssertEqual(sunStates[1].type, .sunrise)
        XCTAssertEqual(sunStates[2].date, sunset)
        XCTAssertEqual(sunStates[2].type, .sunset)
        
        XCTAssertEqual(sunStates.last!.date, tomorrow, "SunStates in range ends with ending date")
        XCTAssertEqual(sunStates.last!.type, .night, "SunStates in range midnight...midnight ends with night")
        
        XCTAssertEqual(sunStates.count, 4)
    }
    
    func testSunStatesNormalRanges() {
        let startDate = Date(timeIntervalSince1970: 1698883200)  // Thursday, November 2, 2023 00:00:00 GMT
        let location = sanDiego.location
        let oneHour = TimeInterval(60.0 * 60.0)
        let oneDay = TimeInterval(24.0 * oneHour)
        
        stride(from: TimeInterval(0), to: oneDay, by: oneHour).forEach {
            let date = startDate.addingTimeInterval($0)
            let events = SunState.states(inRange: date...date.addingTimeInterval(oneDay), at: location)
            
            XCTAssertEqual(events.count, 4)
            XCTAssertEqual(events.filter({ $0.type == .sunrise }).count, 1)
            XCTAssertEqual(events.filter({ $0.type == .sunset }).count, 1)
        }
    }
    
    func testSunStatesLongerRanges() {
        let rangeLengthsInDays = [7, 30, 365]
        let startDate = Date(timeIntervalSince1970: 1698390000)  // Friday, October 27, 2023 07:00:00 GMT
        
        rangeLengthsInDays.forEach {
            let endDate = startDate.addingTimeInterval(Double($0) * 24.0 * 60.0 * 60.0)
            
            let sunStates = SunState.states(inRange: startDate...endDate, at: sanDiego.location)
            
            XCTAssertEqual(sunStates.first!.date, startDate, "SunStates in \($0) day range starts with starting date")
            XCTAssertEqual(sunStates.last!.date, endDate, "SunStates in \($0) day range ends with ending date")
            
            XCTAssertEqual(sunStates.filter({ $0.type == .sunrise }).count, $0,
                           "SunStates in \($0) day range includes \($0) sunrises")
            XCTAssertEqual(sunStates.filter({ $0.type == .sunset }).count, $0,
                           "SunStates in \($0) day range includes \($0) sunsets")
        }
    }
}
