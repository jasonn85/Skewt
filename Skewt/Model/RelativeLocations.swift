//
//  RelativeLocations.swift
//  Skewt
//
//  Created by Jason Neel on 7/2/23.
//

import Foundation
import CoreLocation

typealias Degrees = Double
typealias Radians = Double

extension Degrees {
    var inRadians: Radians { self * .pi / 180.0 }
}

extension Radians {
    var inDegrees: Degrees { self * 180.0 / .pi }
}

enum OrdinalDirection: Degrees {
    case north = 0.0
    case northeast = 45.0
    case east = 90.0
    case southeast = 135.0
    case south = 180.0
    case southwest = 225.0
    case west = 270.0
    case northwest = 315.0
}

extension OrdinalDirection {
    static func closest(toBearing bearing: Degrees) -> Self {
        var eighth = round(bearing / 45.0) * 45.0
        
        while eighth < 0.0 {
            eighth += 360.0
        }
        
        while eighth >= 360.0 {
            eighth -= 360.0
        }
        
        return OrdinalDirection(rawValue: eighth)!
    }
}

extension CLLocation {
    func bearing(toLocation otherLocation: CLLocation) -> Degrees {
        let c1 = (latitude: Degrees(self.coordinate.latitude).inRadians,
                  longitude: Degrees(self.coordinate.longitude).inRadians)
        let c2 = (latitude: Degrees(otherLocation.coordinate.latitude).inRadians,
                  longitude: Degrees(otherLocation.coordinate.longitude).inRadians)
        
        let dLongitude = c2.longitude - c1.longitude
        let y = sin(dLongitude) * cos(c2.latitude)
        let x = cos(c1.latitude) * sin(c2.latitude) - sin(c1.latitude) * cos(c2.latitude) * cos(dLongitude)
        var bearing = Radians(atan2(y, x))
        
        while bearing < 0.0 {
            bearing += 2.0 * .pi
        }
        
        while bearing >= 2.0 * .pi {
            bearing -= 2.0 * .pi
        }
        
        return bearing.inDegrees
    }
    
    func ordinalDirection(toLocation otherLocation: CLLocation) -> OrdinalDirection {
        OrdinalDirection.closest(toBearing: self.bearing(toLocation: otherLocation))
    }
}
