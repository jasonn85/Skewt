//
//  SunlightGradientView.swift
//  Skewt
//
//  Created by Jason Neel on 7/2/24.
//

import SwiftUI
import CoreLocation

struct SunlightGradientView: View {
    let location: CLLocation
    let time: Date
    
    var viewBearing: Double = 0.0
    var horizontalFovDegrees: Double = 90.0
    var verticalFovDegrees: Double = 0.0
    var heightRangeMeters: ClosedRange<Double> = 0.0...15_240.0
    
    init(location: CLLocation? = nil, time: Date? = nil) {
        self.location = location ?? .denver
        self.time = time ?? .now
    }
    
    var body: some View {
        Rectangle()
            .foregroundStyle(ShaderLibrary.skyColor(
                .boundingRect,
                .float(viewBearing * .pi / 180.0),
                .float(horizontalFovDegrees * .pi / 180.0),
                .float(verticalFovDegrees * .pi / 180.0),
                .float2(heightRangeMeters.lowerBound, heightRangeMeters.upperBound),
                .float(time.hourAngle(at: location)),
                .float(time.solarZenithAngle(at: location))
            ))
    }
}

#Preview {
    SunlightGradientView(
        location: .denver,
        time: Date(timeIntervalSince1970: 1720548000)
    )
}
