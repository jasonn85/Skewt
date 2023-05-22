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
        case .done(let sounding):
            return sounding
        default:
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
        // TODO: Use altitudes from current state/settings
        let expectedAltitudes = [0.0, 5_000.0, 10_000.0, 20_000.0,
                                 30_000.0, 40_000.0]
        
        // TODO: guard there are some altitudes and the labels are on else return nil
        
        var widest: CGFloat = 0.0
        
        for altitude in expectedAltitudes {
            let text = altitudeFormatter.string(from: altitude as NSNumber)!
            let attributes = [NSAttributedString.Key.font: leftAxisLabelFont]
            let width = text.size(withAttributes: attributes).width
            
            if width > widest {
                widest = width
            }
        }
        
        return widest
    }
    
    private func xAxisLabelHeight() -> CGFloat? {
        // TODO: guard x axis labels are enabled else return nil
        
        let text = "12334567890"
        let attributes = [NSAttributedString.Key.font: bottomAxisLabelFont]
        return text.size(withAttributes: attributes).height
    }
    
    var body: some View {
        VStack(spacing: 2.0) {
            if let title = sounding?.description {
                Text(title)
            }
            
            GeometryReader { geometry in
                let yAxisLabelWidth = widestAltitudeText() ?? 0.0
                let xAxisLabelHeight = xAxisLabelHeight() ?? 0.0
                let smallestDimension = min(geometry.size.width - yAxisLabelWidth,
                                            geometry.size.height - xAxisLabelHeight)
                let squareSize = CGSize(width: smallestDimension, height: smallestDimension)
                
                let plot = SkewtPlot(sounding: sounding, size: squareSize)
                
                ZStack {
                    SkewtPlotView(plot: plot)
                        .frame(width: plot.size.width, height: plot.size.height)
                        .offset(x: yAxisLabelWidth)
                        .background(Color.gray.opacity(0.05))
                        .environmentObject(store)
                    
                    let altitudeIsobars = plot.altitudeIsobarPaths
                    ForEach(altitudeIsobars.keys.sorted().reversed(), id: \.self) { altitude in
                        Text(altitudeFormatter.string(from: altitude as NSNumber) ?? "")
                            .font(Font(leftAxisLabelFont))
                            .lineLimit(1)
                            .foregroundColor(.blue)
                            .position(y: plot.y(forPressureAltitude: altitude))
                            .offset(x: yAxisLabelWidth, y: 8.0)
                    }
                    
                    let isotherms = plot.isothermPaths
                    
                    ForEach(isotherms.keys.sorted(), id: \.self) { temperature in
                        Text(String(Int(temperature)))
                            .font(Font(bottomAxisLabelFont))
                            .foregroundColor(.red)
                            .position(x: plot.x(forSurfaceTemperature: temperature))
                            .offset(x: yAxisLabelWidth + 8.0, y: smallestDimension + xAxisLabelHeight)
                    }
                }
                .frame(width: smallestDimension + yAxisLabelWidth, height: smallestDimension + xAxisLabelHeight)
            }
        }
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
