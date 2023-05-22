//
//  AnnotatedSkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 5/3/23.
//

import SwiftUI

struct AnnotatedSkewtPlotView: View {
    @EnvironmentObject var store: Store<State>
    
    private var altitudeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.multiplier = 0.001
        return formatter
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
        
        let sampleAltitudes = [0.0, 5_000.0, 10_000.0, 20_000.0,
                               30_000.0, 40_000.0]
        var widest: CGFloat = 0.0
        
        for altitude in sampleAltitudes {
            let text = altitudeFormatter.string(from: altitude as NSNumber)!
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
            
            let plot = plot(withSize: squareSize)
            
            ZStack {
                if case .loading = store.state.currentSoundingState.status {
                    ProgressView().controlSize(.large)
                }
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 8) {
                        yAxisLabelView(withPlot: plot)
                        
                        SkewtPlotView(plot: plot)
                            .frame(width: plot.size.width, height: plot.size.height)
                            .background(Color.gray.opacity(0.05))
                            .environmentObject(store)
                    }
                    
                    xAxisLabelView(withPlot: plot, width: smallestDimension)
                }
            }
            .aspectRatio(1.0, contentMode: .fit)
        }
    }
    
    @ViewBuilder private func yAxisLabelView(withPlot plot: SkewtPlot) -> some View {
        if yAxisLabelWidthOrNil == nil {
            EmptyView()
        } else {
            Rectangle().frame(width: yAxisLabelWidthOrNil!).foregroundColor(.clear).overlay {
                let altitudeIsobars = plot.altitudeIsobarPaths
                ForEach(altitudeIsobars.keys.sorted().reversed(), id: \.self) { altitude in
                    Text(altitudeFormatter.string(from: altitude as NSNumber) ?? "")
                        .font(Font(leftAxisLabelFont))
                        .lineLimit(1)
                        .foregroundColor(.blue)
                        .position(y: plot.y(forPressureAltitude: altitude))
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
                        Text(String(Int(temperature)))
                            .font(Font(bottomAxisLabelFont))
                            .foregroundColor(.red)
                            .position(x: plot.x(forSurfaceTemperature: temperature))
                    }
                }
            }
        }
    }
    
    func plot(withSize size: CGSize) -> SkewtPlot {
        var plot = SkewtPlot(sounding: sounding, size: size)
        plot.applyOptions(store.state.plotOptions)
        return plot
    }
}

struct AnnotatedSkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        let previewData = NSDataAsset(name: "op40-sample")!.data
        let previewDataString = String(decoding: previewData, as: UTF8.self)
        let previewSounding = try! Sounding(fromText: previewDataString)
        let soundingScreenState = SoundingState(selection: SoundingSelection(), status: .done(previewSounding))
        
        let store = Store(
            initial: State(
                currentSoundingState: soundingScreenState,
                defaultSoundingSelection: soundingScreenState.selection,
                plotOptions: PlotOptions(),
                locationState: LocationState()
            ),
            reducer: State.reducer,
            middlewares: []
        )
        
        AnnotatedSkewtPlotView().environmentObject(store)
    }
}
