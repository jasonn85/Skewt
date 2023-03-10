//
//  Thermodynamics.swift
//  Skewt
//
//  Created by Jason Neel on 3/10/23.
//

import Foundation

typealias Pressure = Double   // Pressure in millibars
typealias Altitude = Double   // Altitude in feet

//
//extension Pressure {
//    static let standardSeaLevelMb = 1013.25
//}

enum TemperatureUnit {
    case celsius
    case fahrenheit
    case kelvin
}

struct Temperature: Comparable {
    let value: Double
    let unit: TemperatureUnit
    
    public static let standardSeaLevel = Temperature(15.0, unit: .celsius)
    public static let seaLevelLapseRatePerFoot = Temperature(-0.0019812, unit: .celsius)
    
    private static let celsiusToKelvinDelta = 273.15
    
    init(_ value: Double, unit: TemperatureUnit = .celsius) {
        self.value = value
        self.unit = unit
    }
    
    public func inUnit(_ unit: TemperatureUnit) -> Temperature {
        if unit == self.unit {
            return self
        }
        
        // Convert to Celsius before doing the requested conversion
        switch self.unit {
        case .celsius:
            break
        case .fahrenheit:
            return Temperature((self.value - 32.0) * 5.0 / 9.0, unit: .celsius).inUnit(unit)
        case .kelvin:
            return Temperature(self.value - Temperature.celsiusToKelvinDelta, unit: .celsius).inUnit(unit)
        }
        
        // Now we're Celsius, so...
        switch unit {
        case .celsius:
            return self  // unreachable
        case .fahrenheit:
            return Temperature(self.value * 9.0 / 5.0 + 32.0, unit: .fahrenheit)
        case .kelvin:
            return Temperature(self.value + Temperature.celsiusToKelvinDelta, unit: .kelvin)
        }
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.value == rhs.inUnit(lhs.unit).value
    }
    
    static func < (lhs: Temperature, rhs: Temperature) -> Bool {
        return lhs.value < rhs.inUnit(lhs.unit).value
    }
}
