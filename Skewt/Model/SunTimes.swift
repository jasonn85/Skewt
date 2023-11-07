//
//  SunTimes.swift
//  Skewt
//
//  Created by Jason Neel on 10/16/23.
//

import Foundation
import CoreLocation

extension Double {
    static let sunriseZenith = 1.58533492  // 90.833° zenith for sunrise/sunset
}

extension CLLocation {
    static var equatorialLocationForCurrentTimeZone: CLLocation {
        let calendar = Calendar.current
        let gmtOffset = calendar.timeZone.secondsFromGMT() / 3_600
        
        return CLLocation(latitude: 0.0, longitude: 15.0 * Double(gmtOffset))
    }
}

/// Struct used to represent sun rise/set events during a date range.
/// Day/night events are used to bookend a range.
struct SunState {
    enum StateType: Equatable {
        case day
        case night
        case sunrise
        case sunset
    }
    
    let type: StateType
    let date: Date
}
 
extension SunState {
    private var isDayThereafter: Bool {
        switch type {
        case .day, .sunrise:
            return true
        case .night, .sunset:
            return false
        }
    }
    
    static func states(inRange range: ClosedRange<Date>, at location: CLLocation) -> [SunState] {
        var nextState: SunState? = SunState(
            type: range.lowerBound.isDaylight(at: location) ? .day : .night,
            date: range.lowerBound
        )
        var result: [SunState] = []
        
        repeat {
            result.append(nextState!)
            
            let lookingForSunriseNext = !result.last!.isDayThereafter
            let nextDate = Date.nextSunriseOrSunset(sunrise: lookingForSunriseNext, at: location, afterDate: result.last!.date)
            
            if let nextDate = nextDate, range.upperBound.timeIntervalSince(nextDate) >= 0.0 {
                nextState = SunState(type: lookingForSunriseNext ? .sunrise : .sunset, date: nextDate)
            } else {
                nextState = nil
            }
        } while (nextState != nil)
        
        result.append(SunState(
            type: range.upperBound.isDaylight(at: location) ? .day : .night,
            date: range.upperBound
        ))
        
        return result
    }
}

extension Date {
    // The percent of the year [0,2π], accurate to 24 hours
    var fractionalYearInRadians: Double {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfTheYear = calendar.ordinality(of: .day, in: .year, for: self)!
        let dayRangeThisYear = calendar.range(of: .day, in: .year, for: self)!
        let daysThisYear = dayRangeThisYear.upperBound - dayRangeThisYear.lowerBound

        return 2.0 * .pi / Double(daysThisYear) * Double(dayOfTheYear - 1)
    }
    
    // Solar declination in radians 
    var solarDeclination: Double {
        let fractionalYear = fractionalYearInRadians
        
        return (
            0.006918
            - 0.399912 * cos(fractionalYear) + 0.070257 * sin(fractionalYear)
            - 0.006758 * cos(2.0 * fractionalYear) + 0.000907 * sin(2.0 * fractionalYear)
            - 0.002697 * cos(3.0 * fractionalYear) + 0.00148 * sin(3.0 * fractionalYear)
        )
    }
    
    var equationOfTime: TimeInterval {
        let fractionalYear = fractionalYearInRadians
        
        return 60.0 * 229.18 * (
            0.000075
            + 0.001868 * cos(fractionalYear) - 0.032077 * sin(fractionalYear)
            - 0.014615 * cos(2.0 * fractionalYear) - 0.040849 * sin(2.0 * fractionalYear)
        )
    }
    
    func solarZenithAngle(at location: CLLocation) -> Double {
        let latitude = location.coordinate.latitude * .pi / 180.0
        let solarDeclination = solarDeclination
        let equationOfTime = equationOfTime
        let timeOffset: TimeInterval = equationOfTime + 4.0 * location.coordinate.longitude * 60.0
        
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: .gmt, from: self)
        let solarTime: TimeInterval = (
            Double(components.hour!) * 3600.0
            + Double(components.minute!) * 60.0
            + Double(components.second!)
            + timeOffset
        )
        
        let hourAngle = 15.0 * (solarTime / 3600.0  - 12.0) * .pi / 180.0
            
        return acos(sin(latitude) * sin(solarDeclination) + cos(latitude) * cos(solarDeclination) * cos(hourAngle))
    }
    
    func isDaylight(at location: CLLocation) -> Bool {
        solarZenithAngle(at: location) <= Double.sunriseZenith
    }
    
    // Sunrise or sunset on the same calendar UTC day.
    // Returns nil if the day occurs during polar night or polar day.
    private static func sunriseOrSunset(sunrise: Bool, at location: CLLocation, onDate date: Date = .now) -> Date? {
        let latitude = location.coordinate.latitude * .pi / 180.0
        let solarDeclination = date.solarDeclination
        let sign = sunrise ? 1.0 : -1.0
        let hourAngle = sign * acos((cos(Double.sunriseZenith) / cos(latitude) * cos(solarDeclination)) - tan(latitude) * tan(solarDeclination))

        if hourAngle.isNaN {
            // Polar night or day
            return nil
        }
        
        let minutesUtc = 720.0 - 4.0 * (location.coordinate.longitude + hourAngle * 180.0 / .pi) - (date.equationOfTime / 60.0)
        let secondsUtc = Int(minutesUtc * 60.0)
        
        let calendar = Calendar(identifier: .gregorian)

        var components = calendar.dateComponents(in: .gmt, from: date)
        components.day! += minutesUtc > 1440 ? -1 : (minutesUtc < 0 ? 1 : 0)  // Correct for off-by-one day
        components.hour = 0
        components.minute = 0
        components.nanosecond = 0
        components.second = secondsUtc
        
        return calendar.date(from: components)!
    }
    
    // Sunrise on the same calendar UTC day.
    // Returns nil if the day occurs during polar night or polar day.
    static func sunrise(at location: CLLocation, onDate date: Date = .now) -> Date? {
        sunriseOrSunset(sunrise: true, at: location, onDate: date)
    }
    
    // Sunset on the same calendar UTC day.
    // Returns nil if the day occurs during polar night or polar day.
    static func sunset(at location: CLLocation, onDate date: Date = .now) -> Date? {
        sunriseOrSunset(sunrise: false, at: location, onDate: date)
    }
    
    // Prior sunrise or sunset to a time at a specified location, including appropriate, estimated polar
    //  sunrise/sunset if it is 24+ hours prior.
    static func priorSunriseOrSunset(sunrise: Bool, at location: CLLocation, toDate date: Date = .now) -> Date? {
        let eightMonths = TimeInterval(8.0 * 30.0 * 24.0 * 60.0 * 60.0)
        let minimumDate = date.addingTimeInterval(-eightMonths)
        var date = date
        var result: Date? = nil
        
        while result == nil {
            result = Date.sunriseOrSunset(sunrise: sunrise, at: location, onDate: date)
            date = date.yesterday
            
            if date.timeIntervalSince(minimumDate) < 0.0 {
                return nil
            }
        }
        
        return result!
    }
    
    // Next sunrise or sunset after a time at a specified location, including appropriate, estimated polar
    //  sunrise/sunset if it is 24+ hours hence.
    static func nextSunriseOrSunset(sunrise: Bool, at location: CLLocation, afterDate initialDate: Date = .now) -> Date? {
        let eightMonths = TimeInterval(8.0 * 30.0 * 24.0 * 60.0 * 60.0)
        let maximumDate = initialDate.addingTimeInterval(eightMonths)
        var date = initialDate.addingTimeInterval(-24.0 * 60.0 * 60.0)
        var result: Date? = nil
        
        while result == nil {
            result = Date.sunriseOrSunset(sunrise: sunrise, at: location, onDate: date)
            date = date.tomorrow
            
            if let nonNilResult = result, nonNilResult.timeIntervalSince(initialDate) <= 0.0 {
                result = nil
            }
            
            if date.timeIntervalSince(maximumDate) > 0.0 {
                return nil
            }
        }
        
        return result!
    }
    
    var tomorrow: Date {
        addingTimeInterval(24.0 * 60.0 * 60.0)
    }
    
    var yesterday: Date {
        addingTimeInterval(-24.0 * 60.0 * 60.0)
    }
}
