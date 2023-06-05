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
        let plotStyling = store.state.plotOptions.plotStyling
        
        ZStack() {
            if let temperaturePath = plot.temperaturePath {
                Path(temperaturePath)
                    .applyLineStyle(plotStyling.lineStyle(forType: .temperature))
                    .zIndex(100)
            }
            
            if let dewPointPath = plot.dewPointPath {
                Path(dewPointPath)
                    .applyLineStyle(plotStyling.lineStyle(forType: .dewPoint))
                    .zIndex(99)
            }
            
            ForEach(isobarPaths.keys.sorted(), id: \.self) { a in
                Path(isobarPaths[a]!)
                    .applyLineStyle(isobarStyle)
                    .zIndex(75)
            }
            
            let isotherms = plot.isothermPaths
            
            if case .tens = store.state.plotOptions.isothermTypes {
                ForEach(isotherms.keys.sorted(), id: \.self) { t in
                    Path(isotherms[t]!)
                        .applyLineStyle(plotStyling.lineStyle(forType: .isotherms))
                        .zIndex(25)
                }
            }
            
            if showZeroIsotherm {
                if let zeroIsotherm = isotherms[0.0] {
                    Path(zeroIsotherm)
                        .applyLineStyle(plotStyling.lineStyle(forType: .zeroIsotherm))
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
                        .applyLineStyle(plotStyling.lineStyle(forType: .dryAdiabats))
                        .zIndex(10)
                }
                
                let moistAdiabats = plot.moistAdiabatPaths
                ForEach(moistAdiabats.keys.sorted(), id: \.self) { t in
                    Path(moistAdiabats[t]!)
                        .applyLineStyle(plotStyling.lineStyle(forType: .moistAdiabats))
                        .zIndex(9)
                }
            }
            
            if store.state.plotOptions.showMixingLines {
                let isohumes = plot.isohumePaths
                ForEach(isohumes.keys.sorted(), id: \.self) { t in
                    Path(isohumes[t]!)
                        .applyLineStyle(plotStyling.lineStyle(forType: .isohumes))
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
    
    private var isobarStyle: PlotOptions.PlotStyling.LineStyle {
        let type: PlotOptions.PlotStyling.PlotType = (
            store.state.plotOptions.isobarTypes == .altitude ? .altitudeIsobars : .pressureIsobars
            )
        
        return store.state.plotOptions.plotStyling.lineStyle(forType: type)
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