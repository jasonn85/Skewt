//
//  SoundingLocationList.swift
//  Skewt
//
//  Created by Jason Neel on 6/11/23.
//

import Foundation

enum LocationListParsingError: Error {
    case missingHeader
    case unparseableLine(String)
}

struct LocationList: Codable {
    struct Location: Codable {
        var name: String
        var id: Int
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
        
        guard let headerIndex = lines.firstIndex(where: { $0.hasPrefix("Name") }) else {
            throw LocationListParsingError.missingHeader
        }
        
        locations = try lines[(headerIndex + 1)...].map { try Location(String($0)) }
    }
}

extension LocationList.Location {
    init(_ locationLine: String) throws {
        let pattern = /(\w+)\s+(-?\d+)\s+(-?\d+(\.\d+))\s+(-?\d+(\.\d+))\s+(-?\d+)\s+(.+)/
        
        guard let result = try? pattern.wholeMatch(in: locationLine) else {
            throw LocationListParsingError.unparseableLine(locationLine)
        }
        
        name = String(result.1)
        id = Int(result.2)!
        latitude = Double(result.3)!
        longitude = Double(result.5)!
        elevation = Int(result.7)!
        description = String(result.8)
    }
}
