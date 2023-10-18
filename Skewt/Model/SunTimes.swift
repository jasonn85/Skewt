//
//  SunTimes.swift
//  Skewt
//
//  Created by Jason Neel on 10/16/23.
//

import Foundation
import CoreLocation

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
    
    // Sunrise or sunset on the same calendar UTC day.
    // Returns nil if the day occurs during polar night or polar day.
    private static func sunriseOrSunset(sunrise: Bool, at location: CLLocation, onDate date: Date = .now) -> Date? {
        let zenith = 1.58533492  // 90.833° zenith for sunrise/sunset
        let latitude = location.coordinate.latitude * .pi / 180.0
        let solarDeclination = date.solarDeclination
        let sign = sunrise ? 1.0 : -1.0
        let hourAngle = sign * acos((cos(zenith) / cos(latitude) * cos(solarDeclination)) - tan(latitude) * tan(solarDeclination))

        if hourAngle.isNaN {
            // Polar night or day
            return nil
        }
        
        let minutesUtc = 720.0 - 4.0 * (location.coordinate.longitude + hourAngle * 180.0 / .pi) - (date.equationOfTime / 60.0)
        let secondsUtc = Int(minutesUtc * 60.0)
        
        let calendar = Calendar(identifier: .gregorian)

        var components = calendar.dateComponents(in: .gmt, from: date)
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
    static func nextSunriseOrSunset(sunrise: Bool, at location: CLLocation, afterDate date: Date = .now) -> Date? {
        let eightMonths = TimeInterval(8.0 * 30.0 * 24.0 * 60.0 * 60.0)
        let maximumDate = date.addingTimeInterval(eightMonths)
        var date = date
        var result: Date? = nil
        
        while result == nil {
            result = Date.sunriseOrSunset(sunrise: sunrise, at: location, onDate: date)
            date = date.tomorrow
            
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

// Calculations for sunrise/sunset, ref: https://gml.noaa.gov/grad/solcalc/solareqns.PDF
extension TimeInterval {
    static func timeToNearestSunrise(atLocation location: CLLocation?, referenceDate: Date = .now) -> TimeInterval? {
        let location = location ?? .denver
        let sunriseToday = Date.sunrise(at: location, onDate: referenceDate)
        let sunriseTomorrow = Date.sunrise(at: location, onDate: referenceDate.tomorrow)
        
        guard let sunriseToday = sunriseToday, let sunriseTomorrow = sunriseTomorrow else {
            guard let lastSunrise = Date.priorSunriseOrSunset(sunrise: true, at: location, toDate: referenceDate),
                  let nextSunrise = Date.nextSunriseOrSunset(sunrise: true, at: location, afterDate: referenceDate) else {
                return nil
            }
            
            let lastDiff = lastSunrise.timeIntervalSince(referenceDate)
            let nextDiff = nextSunrise.timeIntervalSince(referenceDate)
            
            return abs(lastDiff) <= abs(nextDiff) ? lastDiff : nextDiff
        }
        
        let todayDiff = sunriseToday.timeIntervalSince(referenceDate)
        let tomorrowDiff = sunriseTomorrow.timeIntervalSince(referenceDate)
        
        return abs(todayDiff) <= abs(tomorrowDiff) ? todayDiff : tomorrowDiff
    }
    
    static func timeToNearestSunset(atLocation location: CLLocation?, referenceDate: Date = .now) -> TimeInterval? {
        let location = location ?? .denver
        let sunsetToday = Date.sunset(at: location, onDate: referenceDate)
        let sunsetYesterday = Date.sunset(at: location, onDate: referenceDate.yesterday)
        
        guard let sunsetToday = sunsetToday, let sunsetYesterday = sunsetYesterday else {
            guard let lastSunset = Date.priorSunriseOrSunset(sunrise: false, at: location, toDate: referenceDate),
                  let nextSunset = Date.nextSunriseOrSunset(sunrise: false, at: location, afterDate: referenceDate) else {
                return nil
            }
            
            let lastDiff = lastSunset.timeIntervalSince(referenceDate)
            let nextDiff = nextSunset.timeIntervalSince(referenceDate)
            
            return abs(lastDiff) <= abs(nextDiff) ? lastDiff : nextDiff
        }
        
        let todayDiff = sunsetToday.timeIntervalSince(referenceDate)
        let yesterdayDiff = sunsetYesterday.timeIntervalSince(referenceDate)
        
        return abs(todayDiff) <= abs(yesterdayDiff) ? todayDiff : yesterdayDiff   
    }
}
