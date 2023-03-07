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

struct SkewtPlot {
    let sounding: Sounding?
    let size: CGSize
    
    // Ranges
    let surfaceTemperatureRange: ClosedRange<Double>
    let pressureRange: ClosedRange<Double>
    
    // Isopleth display parameters
    let isothermSpacing: CGFloat
    let adiabatSpacing: CGFloat
    let isobarSpacing: CGFloat
    
    let skewSlope: CGFloat
    
    var temperaturePath: CGPath? {
        guard let data = sounding?.data.filter({ $0.isPlottable }),
              data.count > 0 else {
            return nil
        }
        
        let path = CGMutablePath()
        path.move(to: point(pressure: data[0].pressure, temperature: data[0].temperature!))
        
        data[1...].forEach {
            path.addLine(to: point(pressure: $0.pressure, temperature: $0.temperature!))
        }
        
        return path
    }
    
    var dewPointPath: CGPath? {
        guard let data = sounding?.data.filter({ $0.isPlottable }),
              data.count > 0 else {
            return nil
        }
        
        let path = CGMutablePath()
        path.move(to: point(pressure: data[0].pressure, temperature: data[0].dewPoint!))
        
        data[1...].forEach {
            path.addLine(to: point(pressure: $0.pressure, temperature: $0.dewPoint!))
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
    }
}

// MARK: - Isopleth paths
extension SkewtPlot {
    typealias Line = (CGPoint, CGPoint)

    var isobarPaths: [CGPath] {
        var isobars: Set<Double> = Set([pressureRange.lowerBound, pressureRange.upperBound])
        let bottomLine = floor(pressureRange.upperBound / isobarSpacing) * isobarSpacing
        isobars.formUnion(stride(from: bottomLine, to: pressureRange.lowerBound, by: -isobarSpacing))
        
        return isobars.map {
            let path = CGMutablePath()
            let y = y(forPressure: $0)
            path.move(to: CGPoint(x: 0.0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            
            return path
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
    
    var isothermPaths: [CGPath] {
        let margin = 5.0
        let (_, topLeftTemperature) = pressureAndTemperature(atPoint: CGPoint(x: margin, y: margin))
        let (_, bottomRightTemperature) = pressureAndTemperature(atPoint: CGPoint(x: size.width - margin,
                                                                                  y: size.height - margin))
        let firstIsotherm = ceil(topLeftTemperature / isothermSpacing) * isothermSpacing
        let lastIsotherm = floor(bottomRightTemperature / isothermSpacing) * isothermSpacing
        
        return stride(from: firstIsotherm, through: lastIsotherm, by: isothermSpacing).map {
            let isotherm = isotherm(forTemperature: $0)
            let path = CGMutablePath()
            path.move(to: isotherm.0)
            path.addLine(to: isotherm.1)
            return path
        }
    }
    
    var dryAdiabatPaths: [CGPath] {
        // TODO
        return []
    }
    
    var moistAdiabatPaths: [CGPath] {
        // TODO
        return []
    }
}

