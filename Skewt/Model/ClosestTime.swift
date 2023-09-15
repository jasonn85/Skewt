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
