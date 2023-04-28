//
//  Thermodynamics.swift
//  Skewt
//
//  Created by Jason Neel on 3/10/23.
//

import Foundation

public typealias Pressure = Double   // Pressure in millibars
public typealias Altitude = Double   // Altitude in feet

extension Double {
    public static let universalGasConstant = 8.3144598  // J / (mol * K)
    public static let gravitationalAcceleration = 9.80665  // m / s^2
    public static let airMolarMass = 0.0289644  // kg / mol
    public static let seaLevelLapseRate = -0.0065  // K / m
    public static let heatOfWaterVaporization = 2_501_000.0  // J / kg
    public static let specificGasConstantDryAir = 287.0  // J / (kg * K)
    public static let specificGasConstantWaterVapor = 461.5  // J / (kg * K)
    public static let gasConstantRatioDryAirToWaterVapor = specificGasConstantDryAir / specificGasConstantWaterVapor
    public static let specificHeatDryAirConstantPressure = 1003.5  // J / (kg * K)
    
    public static let metersPerFoot = 0.3048
}

enum TemperatureUnit {
    case celsius
    case fahrenheit
    case kelvin
}

/// Temperature (double precision), representable and comparable across C, F, and K
struct Temperature: Comparable {
    let value: Double
    let unit: TemperatureUnit
    
    public static let standardSeaLevel = Temperature(15.0, unit: .celsius)
        
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

// Dry lapse
extension Temperature {
    private static let lapseRatePerFoot = 0.00298704
    
    func raiseDryParcel(from a1: Altitude, to a2: Altitude) -> Temperature {
        let dA = a2 - a1
        let dT = Temperature.lapseRatePerFoot * dA
        return Temperature(self.inUnit(.celsius).value - dT)
    }
}

// Moist lapse
extension Temperature {
    // Saturated vapor pressure in Pa
    var saturatedVaporPressure: Double {
        let t = self.inUnit(.kelvin).value
        
        // Vapor pressure implementation from...
        //  Hardy, B., 1998, ITS-90 Formulations for Vapor Pressure, Frostpoint Temperature,
        //  Dewpoint Temperature, and Enhancement Factors in the Range –100 to +100 °C,
        //  The Proceedings of the Third International Symposium on Humidity & Moisture, London, England
        return exp(
            (-2.8365744e3 / pow(t, 2))
            - (6.028076559e3 / t)
            + 1.954263612e1
            - (2.737830188e-2 * t)
            + (1.6261698e-5 * pow(t, 2))
            + (7.0229056e-10 * pow(t, 3))
            - (1.8680009e-13 * pow(t, 4))
            + (2.7150305 * log(t))
        )
    }
}

/// Pressure in millibars
extension Pressure {
    static let standardSeaLevel: Pressure = 1013.25
    
    var inPascals: Double {
        self * 100.0
    }
    
    /// Pressure at a given altitude in the International Standard Atmosphere
    public static func standardPressure(atAltitude altitude: Altitude) -> Pressure {
        let referenceTemperature = Temperature.standardSeaLevel.inUnit(.kelvin).value
        let exponent = -gravitationalAcceleration * airMolarMass / (universalGasConstant * seaLevelLapseRate)
        let numerator = referenceTemperature + (altitude * metersPerFoot * seaLevelLapseRate)
        
        return Pressure.standardSeaLevel * pow(numerator / referenceTemperature, exponent)
    }
}

struct AirParcel {
    let temperature: Temperature
    let pressure: Pressure
    
    var moistLapseRate: Double {
        let t = temperature.inUnit(.kelvin).value
        let p = pressure.inPascals
        
        let vaporPressure = temperature.saturatedVaporPressure
        let mixingRatio = (.gasConstantRatioDryAirToWaterVapor * vaporPressure
                           / (p - vaporPressure))
        let numerator = 1.0 + ((.heatOfWaterVaporization * mixingRatio)
                               / (.specificGasConstantDryAir * t))
        let denominator = (.specificHeatDryAirConstantPressure
                           + ((pow(.heatOfWaterVaporization, 2) * mixingRatio)
                              / (.specificGasConstantWaterVapor * pow(t, 2))))
        
        return 1000.0 * .gravitationalAcceleration * numerator / denominator
    }
}

extension Altitude {
    /// Pressure altitude for a given pressure in the International Standard Atmosphere
    public static func standardAltitude(forPressure pressure: Pressure) -> Altitude {
        let referenceTemperature = Temperature.standardSeaLevel.inUnit(.kelvin).value
        let exponent = universalGasConstant * seaLevelLapseRate / (-gravitationalAcceleration * airMolarMass)
        let base = pressure / Pressure.standardSeaLevel

        let heightInMeters = referenceTemperature * (pow(base, exponent) - 1.0) / seaLevelLapseRate
        return heightInMeters / metersPerFoot
    }
}
