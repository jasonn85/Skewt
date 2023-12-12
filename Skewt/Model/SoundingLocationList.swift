//
//  SoundingLocationList.swift
//  Skewt
//
//  Created by Jason Neel on 6/11/23.
//

import Foundation
import CoreLocation
import UIKit

enum LocationListParsingError: Error {
    case missingData
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

extension LatestSoundingList {
    func lastSoundingTime(forWmoId wmoId: Int) -> Date? {
        soundings.first(where: { $0.stationId == .wmoId(wmoId) })?.timestamp
    }
}

struct LocationList: Codable {
    struct Location: Codable, Hashable, Identifiable {
        var name: String
        var wmoId: Int?
        var latitude: Double
        var longitude: Double
        var elevation: Int
        var description: String
        
        var id: String { name }
    }
    
    var locations: [Location]
}

extension LocationList {
    init(_ s: String) throws {
        let lines = s.split(whereSeparator: \.isNewline).filter { !$0.isEmpty }
        
        locations = lines.compactMap { try? Location(String($0)) }
    }
}

extension LatestSoundingList.Entry {
    var wmoIdOrNil: Int? {
        switch stationId {
        case .wmoId(let id):
            return id
        case .bufr(_):
            return nil
        }
    }
}

extension SoundingSelection.ModelType {
    var assetName: String {
        switch self {
        case .op40:
            return "Metar Locations"
        case .raob:
            return "Sounding Locations"
        }
    }
}

extension LocationList {
    static private var op40Locations = try! LocationList.loadLocationForType(.op40)
    static private var raobLocations = try! LocationList.loadLocationForType(.raob)
    static var allLocations = try! LocationList.loadAllLocations()
    
    static private func loadAllLocations() throws -> Self {
        let lists = SoundingSelection.ModelType.allCases.map { try! Self.forType($0) }
        let locationSet = lists.reduce(Set(), { $0.union($1.locations) })
        
        return LocationList(locations: Array(locationSet))
    }
    
    static private func loadLocationForType(_ type: SoundingSelection.ModelType) throws -> Self {
        guard let asset = NSDataAsset(name: type.assetName),
              let string = String(data: asset.data, encoding: .utf8) else {
            throw LocationListParsingError.missingData
        }
        
        return try LocationList(string)
    }
    
    static func forType(_ type: SoundingSelection.ModelType) throws -> Self {
        switch type {
        case .op40:
            return op40Locations
        case .raob:
            return raobLocations
        }
    }
}

extension LocationList.Location {
    // Note that this implementation with ugly column splitting is literally ten times faster than
    //  Swift's awful regex engine with `/(\w+)\s+(-?\d+)\s+(-?\d+(\.\d+))\s+(-?\d+(\.\d+))\s+(-?\d+)\s+(.+)/`
    init(_ locationLine: String) throws {
        let columns = locationLine.split(maxSplits: 5, omittingEmptySubsequences: true, whereSeparator: \.isWhitespace)

        guard columns.count >= 6,
              Int(columns[1]) != nil || columns[1] == "0",
              let latitude = Double(columns[2]),
              let longitude = Double(columns[3]),
              let elevation = Int(columns[4]) else {
            throw LocationListParsingError.unparseableLine(locationLine)
        }

        name = String(columns[0])
        let wmoIdOrZero = Int(columns[1])
        wmoId = wmoIdOrZero != 0 ? wmoIdOrZero : nil
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        description = String(columns[5])
    }
}

extension LocationList.Location {
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
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
        let now = Date.now
        
        return soundings.filter {
            let thisInterval = now.timeIntervalSince($0.timestamp)
        
            return thisInterval > 0.0 && thisInterval < timeInterval
        }
    }
}

extension LocationList {
    func locationsSortedByProximity(to location: CLLocation, onlyWmoIds wmoIds: [Int]? = nil) -> [Location] {
        var locations = self.locations
        
        if let wmoIds = wmoIds {
            locations = locations.filter { $0.wmoId != nil && wmoIds.contains($0.wmoId!) }
        }
        
        return locations.sorted {
            let first = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            let second = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
            
            return location.distance(from: first) < location.distance(from: second)
        }
    }
}

extension LocationList {
    func locationNamed(_ name: String) -> Location? {
        locations.first { $0.name == name }
    }
    
    func locationsForSearch(_ text: String) -> [Location] {
        let upperText = text.uppercased()
        var matches: [Location] = []
        
        // Put any matches of airport ID at the top
        if upperText.count == 3 || upperText.count == 4 {
            let code = upperText.suffix(3)  // "IAD" if "IAD" or "KIAD"
            
            if let codeMatch = locations.first(where: { $0.name.uppercased() == code }) {
                matches.append(codeMatch)
            }
        }

        // Create an dictionary of text match locations
        let matchPositions = locations.enumerated().reduce(into: Dictionary<Int, String.Index>()) { partialResult, item in
            if let position = item.element.description.uppercased().firstRange(of: upperText) {
                partialResult[item.offset] = position.lowerBound
            }
        }
        
        // Add text matches to the results, with matches occuring earliest in the text being first
        matches.append(contentsOf: matchPositions
            .sorted(by: { $0.value < $1.value })
            .map { locations[$0.key] }
            .filter { !matches.contains($0) }
        )
        
        return matches
    }
}
