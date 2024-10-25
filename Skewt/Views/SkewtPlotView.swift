//
//  SkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 2/24/23.
//

import SwiftUI

struct SkewtPlotView: View {
    let plotOptions: PlotOptions
    let plot: SkewtPlot
    let parcelPoint: CGPoint?
    
    var body: some View {
        let plotStyling = plotOptions.plotStyling
        
        ZStack() {
            if let temperaturePath = plot.temperaturePath {
                PlottedPath(path: temperaturePath)
                    .applyLineStyle(plotStyling.lineStyle(forType: .temperature))
                    .zIndex(100)
            }
            
            if let dewPointPath = plot.dewPointPath {
                PlottedPath(path: dewPointPath)
                    .applyLineStyle(plotStyling.lineStyle(forType: .dewPoint))
                    .zIndex(99)
            }
            
            if let parcelPath = parcelPath {
                PlottedPath(path: parcelPath)
                    .applyLineStyle(plotStyling.lineStyle(forType: .parcel))
                    .zIndex(98)
            }
            
            ForEach(isobarPaths.keys.sorted(), id: \.self) { a in
                PlottedPath(path: isobarPaths[a]!)
                    .applyLineStyle(isobarStyle)
                    .zIndex(75)
            }
            
            let isotherms = plot.isothermPaths
            
            if case .tens = plotOptions.isothermTypes {
                ForEach(isotherms.keys.sorted(), id: \.self) { t in
                    PlottedPath(path: isotherms[t]!)
                        .applyLineStyle(plotStyling.lineStyle(forType: .isotherms))
                        .zIndex(25)
                }
            }
            
            if showZeroIsotherm {
                if let zeroIsotherm = isotherms[0.0] {
                    PlottedPath(path: zeroIsotherm)
                        .applyLineStyle(plotStyling.lineStyle(forType: .zeroIsotherm))
                        .zIndex(50)
                }
            }
            
            switch plotOptions.adiabatTypes {
            case .none:
                // Draw a transparent rectangle instead of an EmptyView so that the plot takes up some space
                // if there is no data at all.
                Rectangle()
                    .foregroundColor(.clear)
            case .tens:
                let dryAdiabats = plot.dryAdiabatPaths
                ForEach(dryAdiabats.keys.sorted(), id: \.self) { t in
                    PlottedPath(path: dryAdiabats[t]!)
                        .applyLineStyle(plotStyling.lineStyle(forType: .dryAdiabats))
                        .zIndex(10)
                }
                
                let moistAdiabats = plot.moistAdiabatPaths
                ForEach(moistAdiabats.keys.sorted(), id: \.self) { t in
                    PlottedPath(path: moistAdiabats[t]!)
                        .applyLineStyle(plotStyling.lineStyle(forType: .moistAdiabats))
                        .zIndex(9)
                }
            }
            
            if plotOptions.showMixingLines {
                let isohumes = plot.isohumePaths
                ForEach(isohumes.keys.sorted(), id: \.self) { t in
                    PlottedPath(path: isohumes[t]!)
                        .applyLineStyle(plotStyling.lineStyle(forType: .isohumes))
                        .zIndex(5)
                }
            }
        }
        .clipped()
    }
    
    private var isobarPaths: [Double: CGPath] {
        switch plotOptions.isobarTypes {
        case .none:
            return [:]
        case .altitude:
            return plot.altitudeIsobarPaths
        case .pressure:
            return plot.isobarPaths
        }
    }
    
    private var parcelPath: CGPath? {
        if plotOptions.showMovableParcel, let parcelPoint = parcelPoint {
            let (pressure, temperature) = plot.pressureAndTemperature(atPoint: parcelPoint)
            
            return plot.parcelPath(forTemperature: temperature, pressure: pressure)
        } else if plotOptions.showSurfaceParcelByDefault {
            return plot.surfaceParcelPath
        }
        
        return nil
    }
    
    private var isobarStyle: PlotOptions.PlotStyling.LineStyle {
        let type: PlotOptions.PlotStyling.PlotType = (
            plotOptions.isobarTypes == .altitude ? .altitudeIsobars : .pressureIsobars
            )
        
        return plotOptions.plotStyling.lineStyle(forType: type)
    }
    
    private var showZeroIsotherm: Bool {
        switch plotOptions.isothermTypes {
        case .tens, .zeroOnly:
            return true
        case .none:
            return false
        }
    }
}

extension CGPath: @unchecked @retroactive Sendable { }

struct PlottedPath: Shape {
    let path: CGPath
    
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.size.width, rect.size.height)
        return Path(path).applying(CGAffineTransformMakeScale(scale, scale))
    }
}

struct SkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geometry in
            let store = Store<SkewtState>.previewStore
            let plot = SkewtPlot(sounding: Store<SkewtState>.previewSounding)
            
            SkewtPlotView(plotOptions: store.state.plotOptions, plot: plot, parcelPoint: nil)
        }
    }
}
