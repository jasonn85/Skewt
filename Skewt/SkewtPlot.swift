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
    
    private let skewSlope = 1.0  // This could maybe vary in future for different aspect ratios
    
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
    func y(forPressure pressure: Double) -> CGFloat {
        let lp = log10(pressure)
        let max = log10(pressureRange.upperBound)
        let min = log10(pressureRange.lowerBound)
        let p = ((lp - min) / (max - min))
        
        return p * size.height
    }
    
    func point(pressure: Double, temperature: Double) -> CGPoint {
        let y = y(forPressure: pressure)
        let surfaceX = ((temperature - surfaceTemperatureRange.lowerBound)
                        / (surfaceTemperatureRange.upperBound - surfaceTemperatureRange.lowerBound)
                        * size.width)
        let skewedX = surfaceX + ((size.height - y) * skewSlope)
        
        return CGPoint(x: skewedX, y: y)
    }
}

// MARK: - Initialization
extension SkewtPlot {
    init(sounding: Sounding?, size: CGSize) {
        self.sounding = sounding
        self.size = size
        
        surfaceTemperatureRange = defaultSurfaceTemperatureRange
        pressureRange = defaultPressureRange
        
        adiabatSpacing = defaultAdiabatSpacing
        isothermSpacing = defaultIsothermSpacing
        isobarSpacing = defaultIsobarSpacing
    }
}

// MARK: - Isopleth paths
extension SkewtPlot {
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
    
    var isothermPaths: [CGPath] {
        // TODO
        return []
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

