//
//  SunTimes.swift
//  Skewt
//
//  Created by Jason Neel on 10/16/23.
//

import Foundation
import CoreLocation

// Calculations for sunrise/sunset, ref: https://gml.noaa.gov/grad/solcalc/solareqns.PDF
extension TimeInterval {
    // Time interval to the closest sunrise, either positive or negative.
    // If no location is provided, Denver, CO local sunrise time is used.
    static func timeToNearestSunrise(atLocation location: CLLocation?, referenceDate: Date = .now) -> TimeInterval {
        let location = location ?? .denver
        let calendar = Calendar(identifier: .gregorian)
        let dayOfTheYear = calendar.ordinality(of: .day, in: .year, for: referenceDate)!
        let dayRangeThisYear = calendar.range(of: .day, in: .year, for: referenceDate)!
        let daysThisYear = dayRangeThisYear.upperBound - dayRangeThisYear.lowerBound
        let fractionalYear = 2.0 * .pi / Double(daysThisYear) * Double(dayOfTheYear - 1)
        
        let equationOfTime = 229.18 * (
            0.000075
            + 0.001868 * cos(fractionalYear) - 0.032077 * sin(fractionalYear)
            - 0.014615 * cos(2.0 * fractionalYear) - 0.040849 * sin(2.0 * fractionalYear)
        )
        
        let solarDeclination = (
            0.006918
            - 0.399912 * cos(fractionalYear) + 0.070257 * sin(fractionalYear)
            - 0.006758 * cos(2.0 * fractionalYear) + 0.000907 * sin(2.0 * fractionalYear)
            - 0.002697 * cos(3.0 * fractionalYear) + 0.00148 * sin(3.0 * fractionalYear)
        )
        
        let zenith = 1.58533492  // 90.833° zenith for sunrise/sunset
        let latitude = location.coordinate.latitude * .pi / 180.0
        let longitude = location.coordinate.longitude * .pi / 180.0
        let hourAngle = acos((cos(zenith) / cos(latitude) * cos(solarDeclination)) - tan(latitude) * tan(solarDeclination))
        
        let sunriseSeconds = 43_200.0 - 4.0 * (longitude + hourAngle) - equationOfTime
        
        var sunriseComponents = calendar.dateComponents(in: .gmt, from: referenceDate)
        sunriseComponents.hour = 0
        sunriseComponents.minute = 0
        sunriseComponents.second = Int(sunriseSeconds)
        
        let sunriseToday = calendar.date(from: sunriseComponents)!
        sunriseComponents.day! += 1
        let sunriseTomorrow = calendar.date(from: sunriseComponents)!
        
        let todayDiff = sunriseToday.timeIntervalSince(referenceDate)
        let tomorrowDiff = sunriseTomorrow.timeIntervalSince(referenceDate)
        
        return abs(todayDiff) < abs(tomorrowDiff) ? todayDiff : tomorrowDiff
    }
    
    static func timeToNearestSunset(atLocation location: CLLocation?, referenceDate: Date = .now) -> TimeInterval {
        //TODO:
        return 0
    }
    
}
