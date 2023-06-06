//
//  AnnotatedSkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 5/3/23.
//

import SwiftUI

struct AnnotatedSkewtPlotView: View {
    @EnvironmentObject var store: Store<SkewtState>
    
    private var altitudeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.multiplier = 0.001
        return formatter
    }
    
    private var pressureFormatter: NumberFormatter {
        return NumberFormatter()
    }
    
    private var isobarFormatter: NumberFormatter {
        switch store.state.plotOptions.isobarTypes {
        case .none, .altitude:
            return altitudeFormatter
        case .pressure:
            return pressureFormatter
        }
    }
    
    private var sounding: Sounding? {
        switch store.state.currentSoundingState.status {
        case .done(let sounding), .refreshing(let sounding):
            return sounding
        case .failed(_), .idle, .loading:
            return nil
        }
    }
    
    private var axisLabelFont: UIFont {
        UIFont.systemFont(ofSize: 12.0)
    }
    
    private var leftAxisLabelFont: UIFont {
        axisLabelFont
    }
    
    private var bottomAxisLabelFont: UIFont {
        axisLabelFont
    }
    
    private func widestAltitudeText() -> CGFloat? {
        guard store.state.plotOptions.showIsobarLabels else {
            return nil
        }
        
        let formatter = isobarFormatter
        let sampleAltitudes = [0.0, 5_000.0, 10_000.0, 20_000.0,
                               30_000.0, 40_000.0]
        let samplePressures = [0.0, 1050.0, 9999.0, 8888.0]
        var widest: CGFloat = 0.0
        var samples: [Double]
        
        switch store.state.plotOptions.isobarTypes {
        case .none, .altitude:
            samples = sampleAltitudes
        case .pressure:
            samples = samplePressures
        }
        
        for sample in samples {
            let text = formatter.string(from: sample as NSNumber)!
            let attributes = [NSAttributedString.Key.font: leftAxisLabelFont]
            let width = text.size(withAttributes: attributes).width
            
            if width > widest {
                widest = width
            }
        }
        
        return widest
    }
    
    private var yAxisLabelWidthOrNil: CGFloat? {
        widestAltitudeText()
    }
    
    private var xAxisLabelHeightOrNil: CGFloat? {
        guard store.state.plotOptions.showIsothermLabels else {
            return nil
        }
        
        let text = "12334567890"
        let attributes = [NSAttributedString.Key.font: bottomAxisLabelFont]
        return text.size(withAttributes: attributes).height
    }
    
    var body: some View {
        GeometryReader { geometry in
            let yAxisLabelWidth = yAxisLabelWidthOrNil ?? 0.0
            let xAxisLabelHeight = xAxisLabelHeightOrNil ?? 0.0
            let smallestDimension = min(geometry.size.width - yAxisLabelWidth,
                                        geometry.size.height - xAxisLabelHeight)
            let squareSize = CGSize(width: smallestDimension, height: smallestDimension)
            
            let plot = plot
            
            ZStack {
                if case .loading = store.state.currentSoundingState.status {
                    ProgressView().controlSize(.large)
                }
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        yAxisLabelView(withPlot: plot)
                        
                        SkewtPlotView(plot: plot)
                            .frame(width: squareSize.width, height: squareSize.height)
                            .environmentObject(store)
                            .background {
                                LinearGradient(
                                    colors: [
                                        Color("LowSkyBlue"), Color("HighSkyBlue")
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            }
                            .border(.black)
                    }
                    
                    xAxisLabelView(withPlot: plot, width: smallestDimension)
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
    
    @ViewBuilder private func yAxisLabelView(withPlot plot: SkewtPlot) -> some View {
        if yAxisLabelWidthOrNil == nil {
            EmptyView()
        } else {
            Rectangle().frame(width: yAxisLabelWidthOrNil!).foregroundColor(.clear).overlay {
                let isobars = isobars(withPlot: plot)
                ForEach(isobars.keys.sorted().reversed(), id: \.self) { key in
                    Text(isobarFormatter.string(from: key as NSNumber) ?? "")
                        .font(Font(leftAxisLabelFont))
                        .lineLimit(1)
                        .foregroundColor(isobarColor)
                        .position(y: yForIsobar(key, inPlot: plot))
                        .offset(x: yAxisLabelWidthOrNil!)
                }
            }
        }
    }
    
    @ViewBuilder private func xAxisLabelView(withPlot plot: SkewtPlot, width: CGFloat) -> some View {
        if xAxisLabelHeightOrNil == nil {
            EmptyView()
        } else {
            Rectangle().frame(width: width, height: xAxisLabelHeightOrNil!).foregroundColor(.clear).overlay {
                if store.state.plotOptions.showIsothermLabels {
                    let isotherms = plot.isothermPaths
                    ForEach(isotherms.keys.sorted(), id: \.self) { temperature in
                        let x = plot.x(forSurfaceTemperature: temperature)
                        if x >= 0 {
                            Text(String(Int(temperature)))
                                .font(Font(bottomAxisLabelFont))
                                .foregroundColor(isothermColor)
                                .position(x: x)
                        }
                    }
                }
            }
        }
    }
    
    private func isobars(withPlot plot: SkewtPlot) -> [Double: CGPath] {
        switch store.state.plotOptions.isobarTypes {
        case .none:
            return [:]
        case .altitude:
            return plot.altitudeIsobarPaths
        case .pressure:
            return plot.isobarPaths
        }
    }
    
    private var isobarColor: Color {
        let type = (
            store.state.plotOptions.isobarTypes == .pressure
            ? PlotOptions.PlotStyling.PlotType.pressureIsobars
            : .altitudeIsobars
            )
        
        guard let cgColor = CGColor.fromHex(
            hexString: store.state.plotOptions.plotStyling.lineStyle(forType: type).color
        ) else {
            return .black
        }
        
        return Color(cgColor: cgColor)
    }
    
    private var isothermColor: Color {
        guard let cgColor = CGColor.fromHex(
            hexString: store.state.plotOptions.plotStyling.lineStyle(forType: .temperature).color
        ) else {
            return .black
        }
        
        return Color(cgColor: cgColor)
    }
    
    private func yForIsobar(_ value: Double, inPlot plot: SkewtPlot) -> CGFloat {
        switch store.state.plotOptions.isobarTypes {
        case .none, .altitude:
            return plot.y(forPressureAltitude: value)
        case .pressure:
            return plot.y(forPressure: value)
        }
    }
    
    private var plot: SkewtPlot {
        var plot = SkewtPlot(sounding: sounding)
        
        if let altitudeRange = store.state.plotOptions.altitudeRange {
            plot.altitudeRange = altitudeRange
        }
        
        return plot
    }
}

struct AnnotatedSkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotatedSkewtPlotView().environmentObject(Store<SkewtState>.previewStore)
    }
}
