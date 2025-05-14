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
    var horizontalFovDegrees: Double = 120.0
    var verticalFovDegrees: Double = 0.0
    var heightRangeMeters: ClosedRange<Double> = 0.0...15_240.0
    
    init(
        location: CLLocation? = nil,
        time: Date? = nil,
        viewBearing: Double = 0.0,
        horizontalFovDegrees: Double = 180.0,
        verticalFovDegrees: Double = 0.0,
        heightRangeMeters: ClosedRange<Double> = 0.0...15_240.0
    ) {
        self.location = location ?? .denver
        self.time = time ?? .now
        
        self.viewBearing = viewBearing
        self.horizontalFovDegrees = horizontalFovDegrees
        self.verticalFovDegrees = verticalFovDegrees
        self.heightRangeMeters = heightRangeMeters
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
    struct SunlightGradientPreview: View {
        static var noonEpochTime = 1720548000.0
        @State var timeInterval: TimeInterval = noonEpochTime
        @State var viewBearing: Double = 0.0
        @State var horizontalFovDegrees: Double = 360.0
        @State var verticalFovDegrees: Double = 0.0
        @State var minHeight: Double = 0.0
        @State var maxHeight: Double = 15_240.0
        
        var body: some View {
            VStack {
                SunlightGradientView(
                    location: .denver,
                    time: Date(timeIntervalSince1970: timeInterval),
                    viewBearing: viewBearing,
                    horizontalFovDegrees: horizontalFovDegrees,
                    verticalFovDegrees: verticalFovDegrees,
                    heightRangeMeters: minHeight...maxHeight
                )
                
                VStack {
                    HStack {
                        Text("-12 hours")
                        Slider(
                            value: $timeInterval,
                            in: SunlightGradientPreview.noonEpochTime-(12.0 * 60.0 * 60.0)...SunlightGradientPreview.noonEpochTime+(12.0 * 60.0 * 60.0)
                        )
                        Text("+12 hours")
                    }
                    
                    HStack {
                        Text("View bearing \(Int(viewBearing))°")
                        Slider(value: $viewBearing, in: 0.0...360.0, step: 1.0)
                    }
                    
                    HStack {
                        Text("Horizontal FOV \(Int(horizontalFovDegrees))°")
                        Slider(value: $horizontalFovDegrees, in: 0.0...360.0, step: 1.0)
                    }
                }
                .padding()
            }
        }
    }
    
    return SunlightGradientPreview()
}
