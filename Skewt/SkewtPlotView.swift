//
//  SkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 2/24/23.
//

import SwiftUI

struct SkewtPlotView: View {
    let state: SoundingScreenState
    
    var body: some View {
        switch state.soundingState {
        case .ready(let sounding):
            GeometryReader { geometry in
                let plot = SkewtPlot(sounding: sounding, size: geometry.size)
                
                Path(plot.temperaturePath!)
                    .stroke(lineWidth: 2.0)
                    .foregroundColor(.red)
                
                Path(plot.dewPointPath!)
                    .stroke(lineWidth: 2.0)
                    .foregroundColor(.blue)
                
                ForEach(plot.isobarPaths, id: \.self) { isobar in
                    Path(isobar)
                        .stroke(lineWidth: 1.0)
                        .foregroundColor(.gray)
                }
                
                ForEach(plot.isothermPaths, id: \.self) { isotherm in
                    Path(isotherm)
                        .stroke(lineWidth: 1.0)
                        .foregroundColor(.gray)
                }
            }
        default:
            Text("Nothing here dawg")
        }
    }
}

struct SkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        let previewData = NSDataAsset(name: "op40-sample")!.data
        let previewDataString = String(decoding: previewData, as: UTF8.self)
        let previewSounding = try! Sounding(fromText: previewDataString)
        let soundingScreenState = SoundingScreenState(soundingState:.ready(previewSounding),
                                                      annotationState: AnnotationState())
        
        SkewtPlotView(state: soundingScreenState)
    }
}
