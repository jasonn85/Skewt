//
//  AnnotatedSkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 5/3/23.
//

import SwiftUI

struct AnnotatedSkewtPlotView: View {
    let state: SoundingScreenState
    let leftAxisLabelWidth = 16.0
    let bottomAxisLabelHeight = 16.0
    
    private var sounding: Sounding? {
        switch state.soundingState {
        case .ready(let s):
            return s
        default:
            return nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let smallestDimension = min(geometry.size.width - leftAxisLabelWidth,
                                        geometry.size.height - bottomAxisLabelHeight)
            let squareSize = CGSize(width: smallestDimension, height: smallestDimension)
            
            let plot = SkewtPlot(sounding: sounding, size: squareSize)
            
            ZStack {
                SkewtPlotView(state: state, plot: plot)
                    .frame(width: plot.size.width, height: plot.size.height)
                    .position(x: geometry.size.width / 2.0 + leftAxisLabelWidth, y: plot.size.height / 2.0)
                
                let altitudeIsobars = plot.altitudeIsobarPaths
                ForEach(altitudeIsobars.keys.sorted().reversed(), id: \.self) { altitude in
                    Text(String(Int(altitude / 1000.0)))
                        .font(.system(size: 12.0))
                        .lineLimit(1)
                        .foregroundColor(.blue)
                        .position(x: leftAxisLabelWidth / 2.0 + 4.0, y: plot.y(forPressureAltitude: altitude))
                }
                
                let isotherms = plot.isothermPaths
                
                ForEach(isotherms.keys.sorted(), id: \.self) { temperature in
                    Text(String(Int(temperature)))
                        .font(.system(size: 12.0))
                        .foregroundColor(.red)
                        .position(x: leftAxisLabelWidth + plot.x(forSurfaceTemperature: temperature) + 8.0, y: smallestDimension + (bottomAxisLabelHeight / 2.0))
                }
            }.frame(width: smallestDimension + leftAxisLabelWidth, height: smallestDimension + bottomAxisLabelHeight)
        }
    }
}

struct AnnotatedSkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        let previewData = NSDataAsset(name: "op40-sample")!.data
        let previewDataString = String(decoding: previewData, as: UTF8.self)
        let previewSounding = try! Sounding(fromText: previewDataString)
        let soundingScreenState = SoundingScreenState(soundingState:.ready(previewSounding),
                                                      annotationState: AnnotationState())
        

        AnnotatedSkewtPlotView(state: soundingScreenState)
    }
}
