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
    let soundingsByStationId: [Int: NCAFSounding]
}

extension NCAFSoundingList {
    init(fromString s: String) throws {
        var result: [Int: NCAFSounding] = [:]
        
        try s.components(separatedBy: CharacterSet(charactersIn: "\u{01}\u{03}"))
             .compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
             .filter { !$0.isEmpty }
             .map(NCAFSounding.init(fromString:))
             .forEach {
                 if let stationId = $0.messages.first?.stationId {
                     result[stationId] = $0
                 }
             }
        
        self.soundingsByStationId = result
    }
}
