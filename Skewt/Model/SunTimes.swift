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
    public var fractionalYearInRadians: Double {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfTheYear = calendar.ordinality(of: .day, in: .year, for: self)!
        let dayRangeThisYear = calendar.range(of: .day, in: .year, for: self)!
        let daysThisYear = dayRangeThisYear.upperBound - dayRangeThisYear.lowerBound

        return 2.0 * .pi / Double(daysThisYear) * Double(dayOfTheYear - 1)
    }
    
    // Solar declination in radians 
    public var solarDeclination: Double {
        let fractionalYear = fractionalYearInRadians
        
        return (
            0.006918
            - 0.399912 * cos(fractionalYear) + 0.070257 * sin(fractionalYear)
            - 0.006758 * cos(2.0 * fractionalYear) + 0.000907 * sin(2.0 * fractionalYear)
            - 0.002697 * cos(3.0 * fractionalYear) + 0.00148 * sin(3.0 * fractionalYear)
        )
    }
    
    public var equationOfTime: TimeInterval {
        let fractionalYear = fractionalYearInRadians
        
        return 60.0 * 229.18 * (
            0.000075
            + 0.001868 * cos(fractionalYear) - 0.032077 * sin(fractionalYear)
            - 0.014615 * cos(2.0 * fractionalYear) - 0.040849 * sin(2.0 * fractionalYear)
        )
    }
}

// Calculations for sunrise/sunset, ref: https://gml.noaa.gov/grad/solcalc/solareqns.PDF
extension TimeInterval {
    // Time interval to the closest sunrise, either positive or negative.
    // If no location is provided, Denver, CO local sunrise time is used.
    static private func timeToNearestSunriseOrSunset(sunrise: Bool, atLocation location: CLLocation?, referenceDate: Date = .now) -> TimeInterval {
        let location = location ?? .denver
        let calendar = Calendar(identifier: .gregorian)
        
        let zenith = 1.58533492  // 90.833° zenith for sunrise/sunset
        let latitude = location.coordinate.latitude * .pi / 180.0
        let solarDeclination = referenceDate.solarDeclination
        let sign = sunrise ? 1.0 : -1.0
        let hourAngle = sign * acos((cos(zenith) / cos(latitude) * cos(solarDeclination)) - tan(latitude) * tan(solarDeclination))
        
        let minutesUtc = 720.0 - 4.0 * (location.coordinate.longitude + hourAngle * 180.0 / .pi) - (referenceDate.equationOfTime / 60.0)
        let secondsUtc = minutesUtc * 60.0
        
        var components = calendar.dateComponents(in: .gmt, from: referenceDate)
        components.hour = 0
        components.minute = 0
        components.second = Int(secondsUtc)
        let today = calendar.date(from: components)!
        
        components.day! += sunrise ? 1 : -1
        let otherDay = calendar.date(from: components)!
        
        let todayDiff = today.timeIntervalSince(referenceDate)
        let otherDiff = otherDay.timeIntervalSince(referenceDate)
        
        return abs(todayDiff) < abs(otherDiff) ? todayDiff : otherDiff
    }
    
    static func timeToNearestSunrise(atLocation location: CLLocation?, referenceDate: Date = .now) -> TimeInterval {
        timeToNearestSunriseOrSunset(sunrise: true, atLocation: location, referenceDate: referenceDate)
    }
    
    static func timeToNearestSunset(atLocation location: CLLocation?, referenceDate: Date = .now) -> TimeInterval {
        timeToNearestSunriseOrSunset(sunrise: false, atLocation: location, referenceDate: referenceDate)
    }
    
}
