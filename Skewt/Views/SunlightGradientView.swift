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
    
    var viewBearing: Double = 0.0  /// Bearing in degrees, 90.0 being east
    var horizontalFovDegrees: Double = 90.0
    
    init(
        location: CLLocation? = nil,
        time: Date? = nil,
        viewBearing: Double = 0.0,
        horizontalFovDegrees: Double = 90.0
    ) {
        self.location = location ?? .denver
        self.time = time ?? .now
        
        self.viewBearing = viewBearing
        self.horizontalFovDegrees = horizontalFovDegrees
    }
    
    var body: some View {
        Rectangle()
            .foregroundStyle(ShaderLibrary.skyColor(
                .boundingRect,
                .float(time.hourAngle(at: location) + viewBearing * .pi / 180.0),
                .float(time.solarZenithAngle(at: location)),
                .float(horizontalFovDegrees * .pi / 180.0)
            ))
    }
}

#Preview {
    struct SunlightGradientPreview: View {
        static var noonEpochTime = 1720548000.0
        @State var timeInterval: TimeInterval = noonEpochTime
        @State var viewBearing: Double = 0.0
        @State var horizontalFovDegrees: Double = 90.0
        
        var body: some View {
            VStack {
                SunlightGradientView(
                    location: .denver,
                    time: Date(timeIntervalSince1970: timeInterval),
                    viewBearing: viewBearing,
                    horizontalFovDegrees: horizontalFovDegrees
                )
                
                VStack {
                    VStack {
                        HStack {
                            Text("-12 hours")
                            Slider(
                                value: $timeInterval,
                                in: SunlightGradientPreview.noonEpochTime-(12.0 * 60.0 * 60.0)...SunlightGradientPreview.noonEpochTime+(12.0 * 60.0 * 60.0)
                            )
                            Text("+12 hours")
                        }
                        Text(Date(timeIntervalSince1970: timeInterval).formatted(date: .omitted, time: .shortened))
                    }
                    
                    HStack {
                        Text("View bearing \(Int(viewBearing))°")
                        Slider(value: $viewBearing, in: 0.0...360.0, step: 1.0)
                    }
                    
                    HStack {
                        Text("Horizontal FOV \(Int(horizontalFovDegrees))°")
                        Slider(value: $horizontalFovDegrees, in: 30.0...120.0, step: 1.0)
                    }
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 20)
                    
                    HStack {
                        Text("Hour angle: \(Date(timeIntervalSince1970: timeInterval).hourAngle(at: .denver) + viewBearing * .pi / 180.0)")
                        Spacer()
                    }
                    
                    HStack {
                        Text("Sun zenith: \(Date(timeIntervalSince1970: timeInterval).solarZenithAngle(at: .denver))")
                        Spacer()
                    }
                }
                .padding()
            }
        }
    }
    
    return SunlightGradientPreview()
}
