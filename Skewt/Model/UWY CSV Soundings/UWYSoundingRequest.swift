//
//  UWYSoundingRequest.swift
//  Skewt
//
//  Created by Jason Neel on 2/16/26.
//

import Foundation

struct UWYSoundingRequest {
    static let apiUrl = URL(string: "http://weather.uwyo.edu/wsgi/sounding")!
    
    let stationId: Int
    let time: SoundingTime
    
    struct SoundingTime {
        let year: Int
        let month: Int
        let day: Int
        let time: Time
        
        enum Time: Int {
            case utc0000 = 0
            case utc1200 = 12
        }
        
        var date: Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .gmt
            
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            components.hour = time.rawValue
            components.minute = 0
            components.second = 0
            
            return calendar.date(from: components)!
        }
    }
    
    var url: URL {
        var components = URLComponents(url: UWYSoundingRequest.apiUrl, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        
        return components.url!
    }
    
    var queryItems: [URLQueryItem] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:00:00"
        dateFormatter.timeZone = .gmt
        
        return [
            URLQueryItem(name: "id", value: String(stationId)),
            URLQueryItem(name: "datetime", value: dateFormatter.string(from: time.date)),
            URLQueryItem(name: "type", value: "TEXT:CSV")
        ]
    }
}

extension UWYSoundingRequest.SoundingTime {
    static func mostRecentSoundingTime(now: Date = Date()) -> UWYSoundingRequest.SoundingTime {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        
        return .init(
            year: components.year!,
            month: components.month!,
            day: components.day!,
            time: components.hour! >= 12 ? .utc1200 : .utc0000
        )
    }
}
