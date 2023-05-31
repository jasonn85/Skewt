//
//  SkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 2/24/23.
//

import SwiftUI

struct SkewtPlotView: View {
    @EnvironmentObject var store: Store<SkewtState>
    let plot: SkewtPlot
    
    var body: some View {
        ZStack() {
            if let temperaturePath = plot.temperaturePath {
                Path(temperaturePath)
                    .stroke(lineWidth: 3.0)
                    .foregroundColor(Color("TemperaturePlot"))
                    .zIndex(100)
            }
            
            if let dewPointPath = plot.dewPointPath {
                Path(dewPointPath)
                    .stroke(lineWidth: 3.0)
                    .foregroundColor(Color("DewPointPlot"))
                    .zIndex(99)
            }
            
            ForEach(isobarPaths.keys.sorted(), id: \.self) { a in
                Path(isobarPaths[a]!)
                    .stroke(lineWidth: 1.0)
                    .foregroundColor(.blue)
                    .zIndex(75)
            }
            
            let isotherms = plot.isothermPaths
            
            if case .tens = store.state.plotOptions.isothermTypes {
                ForEach(isotherms.keys.sorted(), id: \.self) { t in
                    Path(isotherms[t]!)
                        .stroke(lineWidth: 1.0)
                        .foregroundColor(.red)
                        .zIndex(25)
                }
            }
            
            if showZeroIsotherm {
                if let zeroIsotherm = isotherms[0.0] {
                    Path(zeroIsotherm)
                        .stroke(lineWidth: 2.0)
                        .foregroundColor(.red)
                        .zIndex(50)
                }
            }
            
            switch store.state.plotOptions.adiabatTypes {
            case .none:
                EmptyView()
            case .tens:
                let dryAdiabats = plot.dryAdiabatPaths
                ForEach(dryAdiabats.keys.sorted(), id: \.self) { t in
                    Path(dryAdiabats[t]!)
                        .stroke(lineWidth: 1.0)
                        .foregroundColor(.blue)
                        .opacity(0.5)
                        .zIndex(10)
                }
                
                let moistAdiabats = plot.moistAdiabatPaths
                ForEach(moistAdiabats.keys.sorted(), id: \.self) { t in
                    Path(moistAdiabats[t]!)
                        .stroke(lineWidth: 1.0)
                        .foregroundColor(.orange)
                        .opacity(0.5)
                        .zIndex(9)
                }
            }
            
            if store.state.plotOptions.showMixingLines {
                let isohumes = plot.isohumePaths
                ForEach(isohumes.keys.sorted(), id: \.self) { t in
                    Path(isohumes[t]!)
                        .stroke(lineWidth: 1.0)
                        .foregroundColor(.gray)
                        .opacity(0.5)
                        .zIndex(5)
                }
            }
            
        }.frame(width: plot.size.width, height: plot.size.height)
    }
    
    private var isobarPaths: [Double: CGPath] {
        switch store.state.plotOptions.isobarTypes {
        case .none:
            return [:]
        case .altitude:
            return plot.altitudeIsobarPaths
        case .pressure:
            return plot.isobarPaths
        }
    }
    
    private var showZeroIsotherm: Bool {
        switch store.state.plotOptions.isothermTypes {
        case .tens, .zeroOnly:
            return true
        case .none:
            return false
        }
    }
}

struct SkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            let store = Store<SkewtState>.previewStore
            let smallestDimension = min(geometry.size.width, geometry.size.height)
            let squareSize = CGSize(width: smallestDimension, height: smallestDimension)
            let plot = SkewtPlot(sounding: Store<SkewtState>.previewSounding, size: squareSize)
            
            SkewtPlotView(plot: plot).environmentObject(store)
        }
    }
}
