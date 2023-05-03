//
//  SkewtPlot.swift
//  Skewt
//
//  Created by Jason Neel on 3/2/23.
//

import Foundation
import CoreGraphics

fileprivate let defaultSurfaceTemperatureRange = -40.0...50.0
fileprivate let defaultPressureRange = 100...1050.0

fileprivate let defaultAdiabatSpacing = 10.0
fileprivate let defaultIsothermSpacing = defaultAdiabatSpacing
fileprivate let defaultIsobarSpacing = 100.0
fileprivate let defaultSkewSlope = 1.0
fileprivate let defaultIsohumes = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 7.5, 10.0, 15.0, 20.0]
fileprivate let defaultAltitudeIsobars = [0.0, 5_000.0, 10_000.0, 20_000.0,
                                          30_000.0, 40_000.0]

struct SkewtPlot {
    let sounding: Sounding?
    let size: CGSize
    
    // Ranges
    let surfaceTemperatureRange: ClosedRange<Double>
    let pressureRange: ClosedRange<Double>
    
    // Isopleth display parameters
    let isothermSpacing: Double  // in C
    let adiabatSpacing: Double  // in C
    let isobarSpacing: Double  // in mb
    let isohumes: [Double]  // in g/kg
    let altitudeIsobars: [Double]  // in ft
    
    let skewSlope: CGFloat
    
    var temperaturePath: CGPath? {
        guard let data = sounding?.data.filter({ $0.isPlottable }),
              data.count > 0 else {
            return nil
        }
        
        let bounds = CGRect(origin: .zero, size: size)
        let path = CGMutablePath()
        path.move(to: point(pressure: data[0].pressure, temperature: data[0].temperature!))
        
        data[1...].forEach {
            let point = point(pressure: $0.pressure, temperature: $0.temperature!)
            
            if bounds.contains(point) {
                path.addLine(to: point)
            }
        }
        
        return path
    }
    
    var dewPointPath: CGPath? {
        guard let data = sounding?.data.filter({ $0.isPlottable }),
              data.count > 0 else {
            return nil
        }
        
        let bounds = CGRect(origin: .zero, size: size)
        let path = CGMutablePath()
        path.move(to: point(pressure: data[0].pressure, temperature: data[0].dewPoint!))
        
        data[1...].forEach {
            let point = point(pressure: $0.pressure, temperature: $0.dewPoint!)
            
            if bounds.contains(point) {
                path.addLine(to: point)
            }
        }
        
        return path
    }
}

// MARK: - Coordinate calculations (skew and log magic)
extension SkewtPlot {
    public func y(forPressure pressure: Double) -> CGFloat {
        log10(pressure / pressureRange.lowerBound)
        / log10(pressureRange.upperBound / pressureRange.lowerBound)
        * size.height
    }
    
    public func y(forPressureAltitude altitude: Double) -> CGFloat {
        y(forPressure: Pressure.standardPressure(atAltitude: altitude))
    }
    
    public func pressure(atY y: CGFloat) -> Double {
        pressureRange.lowerBound
        * pow(10.0,
              y * log10(pressureRange.upperBound / pressureRange.lowerBound) / size.height)
    }
    
    public func x(forSurfaceTemperature temperature: Double) -> CGFloat {
        ((temperature - surfaceTemperatureRange.lowerBound)
         / (surfaceTemperatureRange.upperBound - surfaceTemperatureRange.lowerBound)
         * size.width)
    }
    
    public func point(pressure: Double, temperature: Double) -> CGPoint {
        let y = y(forPressure: pressure)
        let surfaceX = x(forSurfaceTemperature: temperature)
        let skewedX = surfaceX + ((size.height - y) * skewSlope)
        
        return CGPoint(x: skewedX, y: y)
    }
    
    public func pressureAndTemperature(atPoint point: CGPoint) -> (pressure: Double, temperature: Double) {
        let skewedX = point.x - ((size.height - point.y) * skewSlope)
        let temperature = ((skewedX / size.width)
                            * (surfaceTemperatureRange.upperBound - surfaceTemperatureRange.lowerBound)
                            + surfaceTemperatureRange.lowerBound)
        
        return (pressure: pressure(atY: point.y), temperature: temperature)
    }
}

// MARK: - Initialization
extension SkewtPlot {
    init(sounding: Sounding?, size: CGSize) {
        self.sounding = sounding
        self.size = size
        skewSlope = defaultSkewSlope
        
        surfaceTemperatureRange = defaultSurfaceTemperatureRange
        pressureRange = defaultPressureRange
        
        adiabatSpacing = defaultAdiabatSpacing
        isothermSpacing = defaultIsothermSpacing
        isobarSpacing = defaultIsobarSpacing
        isohumes = defaultIsohumes
        altitudeIsobars = defaultAltitudeIsobars
    }
}

// MARK: - Isopleth paths
extension SkewtPlot {
    typealias Line = (CGPoint, CGPoint)
    
    // Granularity for calculating non-linear isopleths (adiabats and isohumes)
    private static let isoplethDY = 1.0

    var isobarPaths: [Double: CGPath] {
        var isobars: Set<Double> = Set([pressureRange.lowerBound, pressureRange.upperBound])
        let bottomLine = floor(pressureRange.upperBound / isobarSpacing) * isobarSpacing
        isobars.formUnion(stride(from: bottomLine, to: pressureRange.lowerBound, by: -isobarSpacing))
        
        return isobars.reduce(into: [Double: CGPath]()) { (result, pressure) in
            let path = CGMutablePath()
            let y = y(forPressure: pressure)
            path.move(to: CGPoint(x: 0.0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            
            result[pressure] = path
        }
    }
    
    var altitudeIsobarPaths: [Double: CGPath] {
        altitudeIsobars.reduce(into: [Double: CGPath]()) { (result, altitude) in
            let y = y(forPressureAltitude: altitude)
            
            if y > 0.0 && y <= size.height {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0.0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                
                result[altitude] = path
            }
        }
    }
    
    /// Calculates the isotherm line and then crops it to our bounds
    func isotherm(forTemperature temperature: Double) -> Line {
        let surfaceX = x(forSurfaceTemperature: temperature)
        
        let intersectingLeft = surfaceX < 0.0 ? CGPoint(x: 0.0, y: size.height + (surfaceX * skewSlope)) : nil
        let intersectingRightY = size.height - ((size.width - surfaceX) * skewSlope)
        let intersectingRight = intersectingRightY >= 0.0 ? CGPoint(x: size.width, y:intersectingRightY) : nil
        let intersectingTop = intersectingRight == nil ? CGPoint(x: size.height / skewSlope + surfaceX, y: 0.0) : nil
        
        let start = intersectingLeft ?? CGPoint(x: surfaceX, y: size.height)
        let end = intersectingRight ?? intersectingTop!
        
        return (start, end)
    }
    
    /// CGPaths for isotherms, keyed by temperature C
    var isothermPaths: [Double: CGPath] {
        let margin = 5.0
        let (_, topLeftTemperature) = pressureAndTemperature(atPoint: CGPoint(x: margin, y: margin))
        let (_, bottomRightTemperature) = pressureAndTemperature(atPoint: CGPoint(x: size.width - margin,
                                                                                  y: size.height - margin))
        let firstIsotherm = ceil(topLeftTemperature / isothermSpacing) * isothermSpacing
        let lastIsotherm = floor(bottomRightTemperature / isothermSpacing) * isothermSpacing
        
        return stride(from: firstIsotherm, through: lastIsotherm, by: isothermSpacing)
            .reduce(into: [Double: CGPath]()) { (partialResult, t) in
                let isotherm = isotherm(forTemperature: t)
                let path = CGMutablePath()
                path.move(to: isotherm.0)
                path.addLine(to: isotherm.1)
                partialResult[t] = path
            }
    }
    
    /// CGPaths for dry adiabats, keyed by surface temperature C
    var dryAdiabatPaths: [Double: CGPath] {
        let margin = adiabatSpacing * 0.25
        let (_, bottomLeftTemperature) = pressureAndTemperature(atPoint: CGPoint(x: margin, y: size.height))
        
        // Find a value near the top-right for a dry adiabat, then lower a parcel from there to find the adiabat starting point at 0 altitude
        let (topRightPressure, topRightTemperature) = pressureAndTemperature(atPoint: CGPoint(x: size.width - margin, y: margin))
        let topRightAltitude = Altitude.standardAltitude(forPressure: topRightPressure)
        let lastAdiabatStartingTemperature = Temperature(topRightTemperature)
            .temperatureOfDryParcelRaised(from: topRightAltitude, to: 0.0).value(inUnit: .celsius)
        
        let firstAdiabat = ceil(bottomLeftTemperature / adiabatSpacing) * adiabatSpacing
        let lastAdiabat = floor(lastAdiabatStartingTemperature / adiabatSpacing) * adiabatSpacing
        
        return stride(from: firstAdiabat, through: lastAdiabat + margin, by: adiabatSpacing)
            .reduce(into: [Double: CGPath]()) { (partialResult, t) in
                if let adiabat = dryAdiabat(fromTemperature: t, dy: SkewtPlot.isoplethDY) {
                    partialResult[t] = adiabat
                }
            }
    }
    
    /// CGPaths for moist adiabats, keyed by surface temperature C
    var moistAdiabatPaths: [Double: CGPath] {
        let margin = adiabatSpacing * 0.25
        let (_, bottomLeftTemperature) = pressureAndTemperature(atPoint: CGPoint(x: margin, y: size.height))
        let (_, bottomRightTemperature) = pressureAndTemperature(atPoint: CGPoint(x: size.width - margin, y: size.height))

        let firstAdiabat = ceil(bottomLeftTemperature / adiabatSpacing) * adiabatSpacing
        let lastAdiabat = floor(bottomRightTemperature / adiabatSpacing) * adiabatSpacing

        return stride(from: firstAdiabat, to: lastAdiabat + margin, by: adiabatSpacing)
            .reduce(into: [Double: CGPath]()) { (partialResult, t) in
                partialResult[t] = moistAdiabat(fromTemperature: t, dy: SkewtPlot.isoplethDY)
            }
    }
    
    // CGPaths for isohumes, keyed by mixing ratio g/kg
    var isohumePaths: [Double: CGPath] {
        isohumes.reduce(into: [Double: CGPath]()) { (partialResult, mr) in
            partialResult[mr] = isohume(forMixingRatio: mr, dy: SkewtPlot.isoplethDY)
        }
    }
    
    private func dryAdiabat(fromTemperature startingTemperature: Double, dy: CGFloat) -> CGPath? {
        let bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: self.size)
        let path = CGMutablePath()
        let initialY = size.height
        var lastAltitude = Altitude.standardAltitude(forPressure: pressure(atY: initialY))
        var temp = Temperature(startingTemperature)
        
        let firstPoint = CGPoint(x: x(forSurfaceTemperature: temp.value(inUnit: .celsius)), y: initialY)
        if bounds.contains(firstPoint) {
            path.move(to: firstPoint)
        }
        
        for y in stride(from: initialY - dy, to: 0.0, by: -dy) {
            let pressure = pressure(atY: y)
            let altitude = Altitude.standardAltitude(forPressure: pressure)
            temp = temp.temperatureOfDryParcelRaised(from: lastAltitude, to: altitude)
            let point = point(pressure: pressure, temperature: temp.value(inUnit: .celsius))
            
            if bounds.contains(point) {
                if path.isEmpty {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            
            lastAltitude = altitude
        }
                         
        return !path.isEmpty ? path : nil
    }
    
    private func moistAdiabat(fromTemperature startingTemperature: Double, dy: CGFloat) -> CGPath {
        let bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: self.size)
        let path = CGMutablePath()
        let initialY = size.height
        var lastAltitude = Altitude.standardAltitude(forPressure: pressure(atY: initialY))
        var temp = Temperature(startingTemperature)
        
        path.move(to: CGPoint(x: x(forSurfaceTemperature: temp.value(inUnit: .celsius)), y: initialY))
        
        for y in stride(from: initialY - dy, through: 0.0, by: -dy) {
            let pressure = pressure(atY: y)
            let altitude = Altitude.standardAltitude(forPressure: pressure)
            temp = temp.temperatureOfSaturatedParcelRaised(from: lastAltitude, to: altitude, pressure: pressure)
            let point = point(pressure: pressure, temperature: temp.value(inUnit: .celsius))
            
            if bounds.contains(point) {
                path.addLine(to: point)
            }
            
            lastAltitude = altitude
        }
        
        return path
    }
    
    private func isohume(forMixingRatio mixingRatio: Double, dy: CGFloat) -> CGPath {
        let bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: self.size)
        let path = CGMutablePath()
        
        let initialPressure = pressure(atY: size.height)
        let temperature = Temperature.temperature(forMixingRatio: mixingRatio, pressure: initialPressure)
            .value(inUnit: .celsius)
        path.move(to: point(pressure: initialPressure, temperature: temperature))
        
        for y in stride(from: size.height - dy, through: 0.0, by: -dy) {
            let pressure = pressure(atY: y)
            let temperature = Temperature.temperature(forMixingRatio: mixingRatio, pressure: pressure)
                .value(inUnit: .celsius)
            let point = point(pressure: pressure, temperature: temperature)
            
            if bounds.contains(point) {
                path.addLine(to: point)
            }
        }
        
        return path
    }
}

