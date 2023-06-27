//
//  SoundingLocationList.swift
//  Skewt
//
//  Created by Jason Neel on 6/11/23.
//

import Foundation

enum LocationListParsingError: Error {
    case unparseableLine(String)
}

struct LatestSoundingList: Codable, Equatable {
    static let url = URL(string: "https://rucsoundings.noaa.gov/latest_pbraob.txt")!
    
    enum StationId: Codable, Equatable {
        case wmoId(Int)
        case bufr(String)
    }
    
    struct Entry: Codable, Equatable {
        var stationId: StationId
        var timestamp: Date
    }
    
    var soundings: [Entry]
}

struct LocationList: Codable {
    struct Location: Codable {
        var name: String
        var wmoId: Int?
        var latitude: Double
        var longitude: Double
        var elevation: Int
        var description: String
    }
    
    var locations: [Location]
}

extension LocationList {
    init(_ s: String) throws {
        let lines = s.split(whereSeparator: \.isNewline).filter { !$0.isEmpty }
        
        locations = lines.compactMap { try? Location(String($0)) }
    }
}

extension LocationList.Location {
    init(_ locationLine: String) throws {
        let pattern = /(\w+)\s+(-?\d+)\s+(-?\d+(\.\d+))\s+(-?\d+(\.\d+))\s+(-?\d+)\s+(.+)/
        
        guard let result = try? pattern.wholeMatch(in: locationLine) else {
            throw LocationListParsingError.unparseableLine(locationLine)
        }
                
        name = String(result.1)
        wmoId = Int(result.2)! != 0 ? Int(result.2)! : nil
        latitude = Double(result.3)!
        longitude = Double(result.5)!
        elevation = Int(result.7)!
        description = String(result.8)
    }
}

extension LatestSoundingList {
    init(_ s: String) throws {
        let lines = s.split(whereSeparator: \.isNewline)
        soundings = lines.compactMap { Entry(String($0)) }
    }
}

extension LatestSoundingList.Entry {
    init?(_ line: String) {
        let pattern = /(.*),\s*(.*)/
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)!
        
        guard let result = try? pattern.wholeMatch(in: line),
              let timestamp = dateFormatter.date(from: String(result.2)) else {
            return nil
        }
        
        if let stationIdInt = Int(result.1) {
            stationId = .wmoId(stationIdInt)
        } else {
            stationId = .bufr(String(result.1))
        }
        
        self.timestamp = timestamp
    }
}

extension TimeInterval {
    static var twentyFourHours: Self {
        60.0 * 60.0 * 24.0
    }
}

extension LatestSoundingList {
    func recentSoundings(_ timeInterval: TimeInterval = .twentyFourHours) -> [Entry] {
        let now = Date()
        
        return soundings.filter {
            let thisInterval = now.timeIntervalSince($0.timestamp)
        
            return thisInterval > 0.0 && thisInterval < timeInterval
        }
    }
}
