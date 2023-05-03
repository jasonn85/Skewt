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
                let smallestDimension = min(geometry.size.width, geometry.size.height)
                let squareSize = CGSize(width: smallestDimension, height: smallestDimension)
                let plot = SkewtPlot(sounding: sounding, size: squareSize)
                
                HStack() {
                    Spacer()
                    
                    VStack() {
                        Spacer()
                        
                        ZStack() {
                            Path(plot.temperaturePath!)
                                .stroke(lineWidth: 3.0)
                                .foregroundColor(.red)
                            
                            Path(plot.dewPointPath!)
                                .stroke(lineWidth: 3.0)
                                .foregroundColor(.blue)
                            
                            let isobars = plot.isobarPaths
                            ForEach(isobars.keys.sorted(), id: \.self) { p in
                                Path(isobars[p]!)
                                    .stroke(lineWidth: 1.0)
                                    .foregroundColor(.gray)
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
                            
                            let dryAdiabats = plot.dryAdiabatPaths
                            ForEach(dryAdiabats.keys.sorted(), id: \.self) { t in
                                Path(dryAdiabats[t]!)
                                    .stroke(lineWidth: 1.0)
                                    .foregroundColor(.blue)
                            }
                            
                            let moistAdiabats = plot.moistAdiabatPaths
                            ForEach(moistAdiabats.keys.sorted(), id: \.self) { t in
                                Path(moistAdiabats[t]!)
                                    .stroke(lineWidth: 1.0)
                                    .foregroundColor(.orange)
                            }
                            
                            let isohumes = plot.isohumePaths
                            ForEach(isohumes.keys.sorted(), id: \.self) { t in
                                Path(isohumes[t]!)
                                    .stroke(lineWidth: 1.0)
                                    .foregroundColor(.gray)
                            }
                            
                        }.frame(width: smallestDimension, height: smallestDimension)
                        
                        Spacer()
                    }
                    
                    Spacer()
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