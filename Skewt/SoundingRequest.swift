//
//  SoundingRequest.swift
//  Skewt
//
//  Created by Jason Neel on 2/23/23.
//

import Foundation

fileprivate let locationFormatter = SoundingRequestLocationFormatter()

struct SoundingRequest {
    enum Location {
        case name(String)
        case geolocation(latitude: Double, longitude: Double)
    }
    
    private static let rucUrl = "http://rucsoundings.noaa.gov/get_soundings.cgi"
    let location: Location
    let modelName: SoundingType?
    let startTime: Date?
    let endTime: Date?
    let numberOfHours: Int?
    
    init(location: Location,
         modelName: SoundingType? = nil,
         startTime: Date? = nil,
         endTime: Date? = nil,
         numberOfHours: Int? = nil) {
        self.location = location
        self.modelName = modelName
        self.startTime = startTime
        self.endTime = endTime
        self.numberOfHours = numberOfHours
    }
}

class SoundingRequestLocationFormatter {
    private var formatter: NumberFormatter
    
    init(numberOfDecimals: Int = 3) {
        formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = numberOfDecimals
        formatter.maximumFractionDigits = numberOfDecimals
    }
    
    func string(forLocation location: SoundingRequest.Location) -> String {
        switch location {
        case .name(let name):
            return name
        case .geolocation(latitude: let latitude, longitude: let longitude):
            let latitudeString = formatter.string(from: latitude as NSNumber)!
            let longitudeString = formatter.string(from: longitude as NSNumber)!
            return "\(latitudeString),\(longitudeString)"
        }
    }
}

extension SoundingRequest {
    var url: URL {
        var components = URLComponents(string: SoundingRequest.rucUrl)!
        components.queryItems = [URLQueryItem(name: "airport",
                                               value: locationFormatter.string(forLocation: location))]
                                  
        if let modelName = modelName {
            components.queryItems!.append(URLQueryItem(name: "data_source", value: modelName.rawValue))
        }
        
        if let startTime = startTime {
            components.queryItems!.append(URLQueryItem(name: "startSecs",
                                                       value: String(Int(startTime.timeIntervalSince1970))))
        }
        
        if let endTime = endTime {
            components.queryItems!.append(URLQueryItem(name: "endSecs",
                                                       value: String(Int(endTime.timeIntervalSince1970))))
        }
        
        if let numberOfHours = numberOfHours {
            components.queryItems!.append(URLQueryItem(name: "n_hrs", value: String(Int(numberOfHours))))
        }
        
        return components.url!
    }
}
