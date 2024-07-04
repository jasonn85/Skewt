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
    
    init(location: CLLocation? = nil, time: Date? = nil) {
        self.location = location ?? .denver
        self.time = time ?? .now
    }
    
    var body: some View {
        Rectangle()
            .foregroundStyle(ShaderLibrary.skyColor(.boundingRect))
    }
}

#Preview {
    SunlightGradientView()
}
