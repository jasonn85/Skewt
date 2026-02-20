//
//  SoundingMapAnnotation.swift
//  Skewt
//
//  Created by Jason Neel on 2/20/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct SoundingMapAnnotation: View {
    var soundingData: SoundingData
    var plotStyling: PlotOptions.PlotStyling = PlotOptions.PlotStyling()
    
    var body: some View {
        SkewtPlotView(
            plotOptions: plotOptions,
            plot: SkewtPlot(soundingData: soundingData),
            parcelPoint: nil
        )
        .background {
            Rectangle()
                .foregroundStyle(.white)
        }
        .cornerRadius(8)
        .opacity(0.8)
    }
    
    var plotOptions: PlotOptions {
        PlotOptions(
            skew: 1.0,
            showSurfaceParcelByDefault: false,
            showMovableParcel: false,
            isothermTypes: .none,
            isobarTypes: .none,
            adiabatTypes: .none,
            showMixingLines: false,
            showIsobarLabels: false,
            showIsothermLabels: false,
            showWindBarbs: false,
            showAnimatedWind: false,
            plotStyling: plotStyling
        )
    }
}

#Preview {
    SoundingMapAnnotation(soundingData: Store<SkewtState>.previewSoundingList.closestSounding()!.data)
}
