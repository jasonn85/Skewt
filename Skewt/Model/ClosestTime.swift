//
//  ClosestTime.swift
//  Skewt
//
//  Created by Jason Neel on 9/15/23.
//

import Foundation

extension Date {
    static func nearestHour(withIntervalFromNow interval: TimeInterval, hoursPerInterval: Int = 1) -> Date {
        let exactDate = Date(timeIntervalSinceNow: interval)
        
        var intervalBeforeComponents = Calendar.current.dateComponents(in: .current, from: exactDate)
        intervalBeforeComponents.hour = (intervalBeforeComponents.hour! / hoursPerInterval) * hoursPerInterval
        intervalBeforeComponents.minute = 0
        intervalBeforeComponents.second = 0
        intervalBeforeComponents.nanosecond = 0
        let intervalBefore = intervalBeforeComponents.date!
        let intervalAfter = intervalBefore.addingTimeInterval(Double(hoursPerInterval) * 60.0 * 60.0)
        
        let timeSinceIntervalBefore = exactDate.timeIntervalSince(intervalBefore)
        let timeToNextInterval = intervalAfter.timeIntervalSince(exactDate)
        
        return timeSinceIntervalBefore <= timeToNextInterval ? intervalBefore : intervalAfter
    }
}

extension Date {
    static func mostRecentSoundingTime(toDate referenceDate: Date = .now, soundingIntervalInHours: Int = 12) -> Date {
        mostRecentSoundingTimes(toDate: referenceDate, count: 1, soundingIntervalInHours: soundingIntervalInHours).first!
    }

    static func mostRecentSoundingTimes(toDate referenceDate: Date = .now,
                                        count: Int = 10,
                                        soundingIntervalInHours: Int = 12) -> [Date] {
        let calendar = Calendar(identifier: .gregorian)
        let nowComponents = calendar.dateComponents(in: .gmt, from: referenceDate)
        
        var mostRecentSoundingComponents = nowComponents
        mostRecentSoundingComponents.hour = Int(
            floor(Double(nowComponents.hour!) / Double(soundingIntervalInHours))
            * Double(soundingIntervalInHours)
        )
        mostRecentSoundingComponents.minute = 0
        mostRecentSoundingComponents.second = 0
        mostRecentSoundingComponents.nanosecond = 0
        
        var result = [calendar.date(from: mostRecentSoundingComponents)!]
        
        for i in 1..<count {
            var components = mostRecentSoundingComponents
            components.hour! -= (i * soundingIntervalInHours)
            result.append(calendar.date(from: components)!)
        }
        
        return result
    }
}

extension TimeInterval {
    func closestSoundingTime(withCurrentDate currentDate: Date = .now) -> Date {
        let targetTime = Date(timeInterval: self, since: currentDate)
        let soundingPeriodInHours = 12.0
        let calendar = Calendar(identifier: .gregorian)
        let mostRecentSounding = Date.mostRecentSoundingTime(toDate: currentDate)
        
        if targetTime.timeIntervalSince(mostRecentSounding) > 0.0 {
            return mostRecentSounding
        }
        
        var targetTimeComponents = calendar.dateComponents(in: .gmt, from: targetTime)
        targetTimeComponents.hour = Int(((Double(targetTimeComponents.hour!) / soundingPeriodInHours).rounded())
                                        * soundingPeriodInHours)
        
        targetTimeComponents.minute = 0
        targetTimeComponents.second = 0
        targetTimeComponents.nanosecond = 0
        
        return calendar.date(from: targetTimeComponents)!
    }
}
