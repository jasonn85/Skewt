//
//  SkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 2/24/23.
//

import SwiftUI

struct SkewtPlotView: View {
    let state: SoundingScreenState
    let plot: SkewtPlot
    
    var body: some View {
        ZStack() {
            if let temperaturePath = plot.temperaturePath {
                Path(temperaturePath)
                    .stroke(lineWidth: 3.0)
                    .foregroundColor(.red)
            }
            
            if let dewPointPath = plot.dewPointPath {
                Path(dewPointPath)
                    .stroke(lineWidth: 3.0)
                    .foregroundColor(.blue)
            }
            
            
            let altitudeIsobars = plot.altitudeIsobarPaths
            ForEach(altitudeIsobars.keys.sorted(), id: \.self) { a in
                Path(altitudeIsobars[a]!)
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.blue)
            }
            
            let isotherms = plot.isothermPaths
            ForEach(isotherms.keys.sorted(), id: \.self) { t in
                Path(isotherms[t]!)
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.red)
            }
            
            if let zeroIsotherm = isotherms[0.0] {
                Path(zeroIsotherm)
                    .stroke(lineWidth: 2.0)
                    .foregroundColor(.red)
            }
            
            let dryAdiabats = plot.dryAdiabatPaths
            ForEach(dryAdiabats.keys.sorted(), id: \.self) { t in
                Path(dryAdiabats[t]!)
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.blue)
                    .opacity(0.5)
            }
            
            let moistAdiabats = plot.moistAdiabatPaths
            ForEach(moistAdiabats.keys.sorted(), id: \.self) { t in
                Path(moistAdiabats[t]!)
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.orange)
                    .opacity(0.5)
            }
            
            let isohumes = plot.isohumePaths
            ForEach(isohumes.keys.sorted(), id: \.self) { t in
                Path(isohumes[t]!)
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.gray)
                    .opacity(0.5)
            }
            
        }.frame(width: plot.size.width, height: plot.size.height)
    }
}

struct SkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        let previewData = NSDataAsset(name: "op40-sample")!.data
        let previewDataString = String(decoding: previewData, as: UTF8.self)
        let previewSounding = try! Sounding(fromText: previewDataString)
        let soundingScreenState = SoundingScreenState(soundingState:.ready(previewSounding),
                                                      annotationState: AnnotationState())
        
        GeometryReader { geometry in
            let smallestDimension = min(geometry.size.width, geometry.size.height)
            let squareSize = CGSize(width: smallestDimension, height: smallestDimension)
            let plot = SkewtPlot(sounding: previewSounding, size: squareSize)
            
            SkewtPlotView(state: soundingScreenState, plot: plot)
        }
        
    }
}
