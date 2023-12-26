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
fileprivate let defaultSkew = 1.0
fileprivate let defaultIsohumes = [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 7.5, 10.0, 15.0, 20.0]
fileprivate let defaultAltitudeIsobars = [0.0, 5_000.0, 10_000.0, 20_000.0,
                                          30_000.0, 40_000.0]

struct SkewtPlot {
    var sounding: Sounding?
    
    // Ranges
    var surfaceTemperatureRange: ClosedRange<Double>
    var pressureRange: ClosedRange<Double>
    var altitudeRange: ClosedRange<Double> {
        get {
            let low = Altitude.standardAltitude(forPressure: pressureRange.upperBound)
            let high = Altitude.standardAltitude(forPressure: pressureRange.lowerBound)
            
            return low...high
        }
        set {
            let low = Pressure.standardPressure(atAltitude: newValue.upperBound)
            let high = Pressure.standardPressure(atAltitude: newValue.lowerBound)
            
            pressureRange = low...high
        }
    }
    
    // Isopleth display parameters
    var isothermSpacing: Double  // in C
    var adiabatSpacing: Double  // in C
    var isobarSpacing: Double  // in mb
    var isohumes: [Double]  // in g/kg
    var altitudeIsobars: [Double]  // in ft
    
    var skew: CGFloat
    
    var temperaturePath: CGPath? {
        guard let data = sounding?.data.filter({ $0.temperature != nil }),
              data.count > 0 else {
            return nil
        }
        
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let path = CGMutablePath()
        var lastPoint = point(pressure: data[0].pressure, temperature: data[0].temperature!)
        path.move(to: lastPoint)
        
        data[1...].forEach {
            let point = point(pressure: $0.pressure, temperature: $0.temperature!)
            
            if bounds.contains(lastPoint) || bounds.contains(point) {
                path.addLine(to: point)
            } else {
                path.move(to: point)
            }
    
            lastPoint = point
        }
        
        return path
    }
    
    var dewPointPath: CGPath? {
        guard let data = sounding?.data.filter({ $0.dewPoint != nil }),
              data.count > 0 else {
            return nil
        }
        
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let path = CGMutablePath()
        var lastPoint = point(pressure: data[0].pressure, temperature: data[0].dewPoint!)
        path.move(to: lastPoint)
        
        data[1...].forEach {
            let point = point(pressure: $0.pressure, temperature: $0.dewPoint!)
            
            if bounds.contains(lastPoint) || bounds.contains(point) {
                path.addLine(to: point)
            } else {
                path.move(to: point)
            }
            
            lastPoint = point
        }
        
        return path
    }
}

// MARK: - Coordinate calculations (skew and log magic)
extension SkewtPlot {
    public func y(forPressure pressure: Double) -> CGFloat {
        log10(pressure / pressureRange.lowerBound)
        / log10(pressureRange.upperBound / pressureRange.lowerBound)
    }
    
    public func y(forPressureAltitude altitude: Double) -> CGFloat {
        y(forPressure: Pressure.standardPressure(atAltitude: altitude))
    }
    
    public func pressure(atY y: CGFloat) -> Double {
        pressureRange.lowerBound
        * pow(10.0,
              y * log10(pressureRange.upperBound / pressureRange.lowerBound))
    }
    
    public func x(forSurfaceTemperature temperature: Double) -> CGFloat {
        ((temperature - surfaceTemperatureRange.lowerBound)
         / (surfaceTemperatureRange.upperBound - surfaceTemperatureRange.lowerBound))
    }
    
    public func point(pressure: Double, temperature: Double) -> CGPoint {
        let y = y(forPressure: pressure)
        let surfaceX = x(forSurfaceTemperature: temperature)
        let skewedX = surfaceX + ((1.0 - y) * skew)
        
        return CGPoint(x: skewedX, y: y)
    }
    
    public func pressureAndTemperature(atPoint point: CGPoint) -> (pressure: Double, temperature: Double) {
        let skewedX = point.x - ((1.0 - point.y) * skew)
        let temperature = (skewedX
                            * (surfaceTemperatureRange.upperBound - surfaceTemperatureRange.lowerBound)
                            + surfaceTemperatureRange.lowerBound)
        
        return (pressure: pressure(atY: point.y), temperature: temperature)
    }
    
    public func closestTemperatureAndDewPointData(toY y: CGFloat) -> (temperature: LevelDataPoint, 
                                                                      dewPoint: LevelDataPoint)? {
        let pressure = pressure(atY: y)

        guard let sounding = sounding,
              let temperature = sounding.closestValue(toPressure: pressure, withValueFor: \.temperature),
              let dewPoint = sounding.closestValue(toPressure: pressure, withValueFor: \.dewPoint) else {
                  return nil
              }
        
        return (temperature, dewPoint)
    }
    
    public func temperatureAndDewPoint(nearestY y: CGFloat) -> (temperature: Double, dewPoint: Double)? {
        let pressure = pressure(atY: y)

        guard let sounding = sounding,
              let temperature = sounding.interpolatedValue(for: \.temperature, atPressure: pressure),
              let dewPoint = sounding.interpolatedValue(for: \.dewPoint, atPressure: pressure) else {
            return nil
        }
        
        return (temperature, dewPoint)
    }
}

// MARK: - Initialization
extension SkewtPlot {
    init(sounding: Sounding?) {
        self.sounding = sounding
        skew = defaultSkew
        
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
    private static let isoplethDY = 1.0 / 500.0

    var isobarPaths: [Double: CGPath] {
        var isobars: Set<Double> = Set([pressureRange.lowerBound, pressureRange.upperBound])
        let bottomLine = floor(pressureRange.upperBound / isobarSpacing) * isobarSpacing
        isobars.formUnion(stride(from: bottomLine, to: pressureRange.lowerBound, by: -isobarSpacing))
        
        return isobars.reduce(into: [Double: CGPath]()) { (result, pressure) in
            let path = CGMutablePath()
            let y = y(forPressure: pressure)
            path.move(to: CGPoint(x: 0.0, y: y))
            path.addLine(to: CGPoint(x: 1.0, y: y))
            
            result[pressure] = path
        }
    }
    
    var altitudeIsobarPaths: [Double: CGPath] {
        altitudeIsobars.reduce(into: [Double: CGPath]()) { (result, altitude) in
            let y = y(forPressureAltitude: altitude)
            
            if y > 0.0 && y <= 1.0 {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0.0, y: y))
                path.addLine(to: CGPoint(x: 1.0, y: y))
                
                result[altitude] = path
            }
        }
    }
    
    /// Calculates the isotherm line and then crops it to our bounds
    func isotherm(forTemperature temperature: Double) -> Line {
        let surfaceX = x(forSurfaceTemperature: temperature)
        let start = CGPoint(x: surfaceX, y: 1.0)
        let end = CGPoint(x: surfaceX + skew, y: 0.0)
        
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        
        return bounds.constrainLine((start, end)) ?? (.zero, .zero)
    }
    
    /// CGPaths for isotherms, keyed by temperature C
    var isothermPaths: [Double: CGPath] {
        let margin: CGFloat = 0.05
        let (_, topLeftTemperature) = pressureAndTemperature(atPoint: CGPoint(x: margin, y: margin))
        let (_, bottomRightTemperature) = pressureAndTemperature(atPoint: CGPoint(x: 1.0 - margin,
                                                                                  y: 1.0 - margin))
        let firstIsotherm = ceil(topLeftTemperature / isothermSpacing) * isothermSpacing
        let lastIsotherm = floor(bottomRightTemperature / isothermSpacing) * isothermSpacing
        
        return stride(from: firstIsotherm, through: lastIsotherm, by: isothermSpacing)
            .reduce(into: [Double: CGPath]()) { (result, t) in
                let isotherm = isotherm(forTemperature: t)
                let path = CGMutablePath()
                path.move(to: isotherm.0)
                path.addLine(to: isotherm.1)
                result[t] = path
            }
    }
    
    /// CGPaths for dry adiabats, keyed by surface temperature C
    var dryAdiabatPaths: [Double: CGPath] {
        let margin = 0.05
        let (_, bottomLeftTemperature) = pressureAndTemperature(atPoint: CGPoint(x: margin, y: 1.0))
        
        // Find a value near the top-right for a dry adiabat, then lower a parcel from there to find the adiabat starting point at 0 altitude
        let (topRightPressure, topRightTemperature) = pressureAndTemperature(atPoint: CGPoint(x: 1.0 - margin, y: margin))
        let topRightAltitude = Altitude.standardAltitude(forPressure: topRightPressure)
        let lastAdiabatStartingTemperature = Temperature(topRightTemperature)
            .temperatureOfDryParcelRaised(from: topRightAltitude, to: 0.0).value(inUnit: .celsius)
        
        let firstAdiabat = ceil(bottomLeftTemperature / adiabatSpacing) * adiabatSpacing
        let lastAdiabat = floor(lastAdiabatStartingTemperature / adiabatSpacing) * adiabatSpacing
        
        return stride(from: firstAdiabat, through: lastAdiabat + margin, by: adiabatSpacing)
            .reduce(into: [Double: CGPath]()) { (result, t) in
                if let adiabat = dryAdiabat(fromTemperature: t, dy: SkewtPlot.isoplethDY) {
                    result[t] = adiabat
                }
            }
    }
    
    /// CGPaths for moist adiabats, keyed by surface temperature C
    var moistAdiabatPaths: [Double: CGPath] {
        let margin = 0.05
        let (_, bottomLeftTemperature) = pressureAndTemperature(atPoint: CGPoint(x: margin, y: 1.0))
        let (_, bottomRightTemperature) = pressureAndTemperature(atPoint: CGPoint(x: 1.0 - margin, y: 1.0))

        let firstAdiabat = ceil(bottomLeftTemperature / adiabatSpacing) * adiabatSpacing
        let lastAdiabat = floor(bottomRightTemperature / adiabatSpacing) * adiabatSpacing

        return stride(from: firstAdiabat, to: lastAdiabat + margin, by: adiabatSpacing)
            .reduce(into: [Double: CGPath]()) { (result, t) in
                result[t] = moistAdiabat(fromTemperature: t, dy: SkewtPlot.isoplethDY)
            }
    }
    
    // CGPaths for isohumes, keyed by mixing ratio g/kg
    var isohumePaths: [Double: CGPath] {
        isohumes.reduce(into: [Double: CGPath]()) { (result, mr) in
            result[mr] = isohume(forMixingRatio: mr, dy: SkewtPlot.isoplethDY)
        }
    }
    
    private func dryAdiabat(fromTemperature startingTemperature: Double, dy: CGFloat) -> CGPath? {
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let path = CGMutablePath()
        let initialY: CGFloat = 1.0
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
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let path = CGMutablePath()
        let initialY: CGFloat = 1.0
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
            } else {
                break
            }
            
            lastAltitude = altitude
        }
        
        return path
    }
    
    private func isohume(forMixingRatio mixingRatio: Double, dy: CGFloat) -> CGPath {
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let path = CGMutablePath()
        
        let initialPressure = pressure(atY: 1.0)
        let temperature = Temperature.temperature(forMixingRatio: mixingRatio, pressure: initialPressure)
            .value(inUnit: .celsius)
        path.move(to: point(pressure: initialPressure, temperature: temperature))
        
        for y in stride(from: 1.0 - dy, through: 0.0, by: -dy) {
            let pressure = pressure(atY: y)
            let temperature = Temperature.temperature(forMixingRatio: mixingRatio, pressure: pressure)
                .value(inUnit: .celsius)
            let point = point(pressure: pressure, temperature: temperature)
            
            if bounds.contains(point) {
                path.addLine(to: point)
            } else {
                break
            }
        }
        
        return path
    }
}

extension CGRect {
    /// Return the entire line if it is fully contained by the CGRect, a segment of the line that intersects the bounds of the CGRect,
    /// or nil if it does not intersect the CGRect
    func constrainLine(_ line: SkewtPlot.Line) -> SkewtPlot.Line? {
        guard line.0.x != line.1.x else {
            return constrainVerticalOrHorizontalLine(line)
        }
        
        let xSorted = [line.0, line.1].sorted { $0.x < $1.x }
        let ySorted = [line.0, line.1].sorted { $0.y < $1.y }
        let left = xSorted[0]
        let right = xSorted[1]
        let bottom = ySorted[0]
        let top = ySorted[1]
        let originallySwapped = left != line.0
                
        let a = (right.y - left.y) / (right.x - left.x)
        let b = -left.x * a + left.y
        let fx: (CGFloat) -> CGFloat = { a * $0 + b }
        let fy: (CGFloat) -> CGFloat = { (b - $0) / a }
        
        guard a != 0 else {
            return constrainVerticalOrHorizontalLine(line)
        }
        
        let x0 = CGPoint(x: origin.x, y: fx(origin.x))
        let x1 = CGPoint(x: origin.x + size.width, y: fx(origin.x + size.width))
        let y0 = CGPoint(x: fy(origin.y), y: origin.y)
        let y1 = CGPoint(x: fy(origin.y + size.height), y: origin.y + size.height)
        
        let possibleLefts = [left, x0, y0, y1, x1].filter { self.containsIncludingEdge($0) }
        let possibleRights = [right, x1, y1, y0, x0].filter { self.containsIncludingEdge($0) }
        
        guard var newLeft = possibleLefts.first, var newRight = possibleRights.first(where: { $0 != newLeft }) else {
            return nil
        }
        
        if (newRight.y - newLeft.y).sign != a.sign {
            swap(&newLeft, &newRight)
        }
        
        if originallySwapped {
            swap(&newLeft, &newRight)
        }
        
        return (newLeft, newRight)
    }
    
    private func constrainVerticalOrHorizontalLine(_ line: SkewtPlot.Line) -> SkewtPlot.Line? {
        (
            CGPoint(
                x: max(origin.x, min(origin.x + size.width, line.0.x)),
                y: max(origin.y, min(origin.y + size.height, line.0.y))
            ),
            CGPoint(
                x: max(origin.x, min(origin.x + size.width, line.1.x)),
                y: max(origin.y, min(origin.y + size.height, line.1.y))
            )
        )
    }
    
    private func containsIncludingEdge(_ point: CGPoint) -> Bool {
        point.x >= origin.x && point.x <= origin.x + size.width && point.y >= origin.y && point.y <= origin.y + size.height
    }
}

