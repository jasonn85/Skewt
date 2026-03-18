//
//  SoundingWindData.swift
//  Skewt
//
//  Created by Jason Neel on 11/10/23.
//

import Foundation

extension SoundingData.Point {
    var windComponents: (n: Double, e: Double)? {
        guard let windSpeed = windSpeed, let windDirection = windDirection else {
            return nil
        }
        
        let speed = Double(windSpeed)
        let direction = Double(windDirection) * .pi / 180.0
        
        return (n: speed * cos(direction), e: speed * sin(direction))
    }
}

extension SoundingData {
    /// All data points in the sounding that contain wind data
    var windData: [Point] {
        dataPoints.filter { $0.windSpeed != nil && $0.windDirection != nil }
    }
    
    /// Wind data as north/east components
    var windDataDirectionalComponents: [(n: Double, e: Double)] {
        windData.map { $0.windComponents! }
    }
}

struct ReducedWindDataPoint {
    let pressure: Double
    let windMagnitude: Double
}

extension SoundingData {
    typealias WindReducer = @Sendable (Int, Double) -> Double
    
    static let magnitudeWindReducer: WindReducer = { _, speed in Double(speed) }
    
    private static func windComponents(direction: Int, speed: Double) -> (n: Double, e: Double) {
        let angle = Double(direction) * .pi / 180.0
        return (n: speed * cos(angle), e: speed * sin(angle))
    }
    
    func maximumWindReducer() -> WindReducer {
        let windData = windData
        
        guard windData.count > 0 else {
            return SoundingData.magnitudeWindReducer
        }
        
        let maximumWindPoint = windData.reduce(windData.first!) { $1.windSpeed! > $0.windSpeed! ? $1 : $0 }
        let maximumWindAngle: Double = {
            var angle = Double(maximumWindPoint.windDirection!) * .pi / 180.0
            
            // Pick an easterly direction so that westerly values will be negative when reduced
            if angle >= .pi {
                angle -= .pi
            }
            
            return angle
        }()
        
        return { direction, speed in
            let thisAngle = Double(direction) * .pi / 180.0
            
            return cos(thisAngle - maximumWindAngle) * Double(speed)
        }
    }
    
    func pcaWindReducer() -> WindReducer {
        let windData = windData
        
        guard windData.count > 1 else {
            return maximumWindReducer()
        }
        
        let components = windData.map {
            SoundingData.windComponents(direction: $0.windDirection!, speed: Double($0.windSpeed!))
        }
        
        let meanN = components.reduce(0.0) { $0 + $1.n } / Double(components.count)
        let meanE = components.reduce(0.0) { $0 + $1.e } / Double(components.count)
        
        let covariance = components.reduce(into: (nn: 0.0, ne: 0.0, ee: 0.0)) { partialResult, component in
            let centeredN = component.n - meanN
            let centeredE = component.e - meanE
            partialResult.nn += centeredN * centeredN
            partialResult.ne += centeredN * centeredE
            partialResult.ee += centeredE * centeredE
        }
        
        let trace = covariance.nn + covariance.ee
        let determinantTerm = (covariance.nn - covariance.ee) * (covariance.nn - covariance.ee) + 4.0 * covariance.ne * covariance.ne
        let principalEigenvalue = 0.5 * (trace + sqrt(max(determinantTerm, 0.0)))
        
        var principalAxis = (
            n: covariance.ne,
            e: principalEigenvalue - covariance.nn
        )
        
        if abs(principalAxis.n) < 1e-10 && abs(principalAxis.e) < 1e-10 {
            principalAxis = (
                n: principalEigenvalue - covariance.ee,
                e: covariance.ne
            )
        }
        
        let axisMagnitude = sqrt(principalAxis.n * principalAxis.n + principalAxis.e * principalAxis.e)
        
        guard axisMagnitude > 0.0 else {
            return maximumWindReducer()
        }
        
        var normalizedAxis = (
            n: principalAxis.n / axisMagnitude,
            e: principalAxis.e / axisMagnitude
        )
        
        // Pick an easterly direction so that westerly values remain negative when reduced.
        if normalizedAxis.e < 0.0 {
            normalizedAxis.n *= -1.0
            normalizedAxis.e *= -1.0
        }
        
        let axis = normalizedAxis
        
        return { direction, speed in
            let components = SoundingData.windComponents(direction: direction, speed: speed)
            return components.n * axis.n + components.e * axis.e
        }
    }
    
    func reducedWindData(_ reducer: WindReducer) -> [ReducedWindDataPoint] {
        windData.map {
            ReducedWindDataPoint(pressure: $0.pressure, windMagnitude: reducer($0.windDirection!, $0.windSpeed!))
        }
    }
}
