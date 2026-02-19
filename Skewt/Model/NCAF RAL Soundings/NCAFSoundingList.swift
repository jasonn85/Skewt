//
//  NCAFSoundingList.swift
//  Skewt
//
//  Created by Jason Neel on 2/8/26.
//

import Foundation

/// A collection of the latest sounding data for all locations served by
/// https://weather.rap.ucar.edu/data/upper/Current.rawins
struct NCAFSoundingList {
    let messagesByStationId: [Int: [NCAFSoundingMessage]]
    let timestamp: Date
    
    static let url = URL(string: "https://weather.rap.ucar.edu/data/upper/Current.rawins")!
    
    func soundingData(forStationId stationId: Int) -> SoundingData? {
        guard let messages = messagesByStationId[stationId],
              let firstMessage = messages.first else {
            return nil
        }
        
        let levels = messages
            .flatMap(\.levels)
            .sorted {
                if $0.key == .surface {
                    return true
                } else if $1.key == .surface {
                    return false
                } else {
                    return $0.key.pressure ?? .infinity > $1.key.pressure ?? .infinity
                }
            }
        
        return SoundingData(
            time: Date.dateOfSounding(onDay: firstMessage.day, utcHour: firstMessage.hour),
            dataPoints: levels.compactMap(\.value.soundingDataPoint),
            surfaceDataPoint: levels.first { $0.key == .surface }?.value.soundingDataPoint,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )
    }
}

extension NCAFSoundingList {
    init?(fromString s: String) {
        var messagesByStationId: [Int: [NCAFSoundingMessage]] = [:]
        
        s.components(separatedBy: CharacterSet(charactersIn: "\u{01}\u{03}"))
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap(NCAFReport.init(fromString:))
            .forEach { report in
                report.messages.forEach { message in
                    guard !message.levels.isEmpty else {
                        return
                    }

                    let existingMessagesThisStation = messagesByStationId[message.stationId]
                    
                    guard existingMessagesThisStation == nil || !existingMessagesThisStation!.contains(message) else {
                        return
                    }
                    
                    messagesByStationId[message.stationId, default: []].append(message)
                }
            }
        
        guard messagesByStationId.count > 0 else {
            return nil
        }
        
        self.messagesByStationId = messagesByStationId
        self.timestamp = .now
    }
}

extension NCAFSoundingMessage.LevelType {
    var pressure: Double? {
        switch self {
        case .mandatory(let pressure),
                .maximumWind(let pressure),
                .significant(let pressure),
                .tropopause(let pressure):
            return pressure
        case .altitude(_), .surface:
            return nil
        }
    }
}

extension Date {
    static func dateOfSounding(onDay day: Int, utcHour hour: Int, currentDate now: Date = .now) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        
        if day > components.day! {
            if components.month! > 1 {
                components.month = components.month! - 1
            } else {
                components.year = components.year! - 1
                components.month = 12
            }
        }
        
        components.day = day
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components)!
    }
}
