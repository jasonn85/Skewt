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
    
    var temperaturePath: CGPath? {
        //TODO
        return nil
        
//        guard let sounding = sounding else {
//            return nil
//        }
    }
    
    var dewPointPath: CGPath? {
        // TODO
        return nil
        
//        guard let sounding = sounding else {
//            return nil
//        }
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
            var path = CGMutablePath()
            path.move(to: CGPoint(x: 0.0, y: $0))
            path.addLine(to: CGPoint(x: size.width, y: $0))
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

