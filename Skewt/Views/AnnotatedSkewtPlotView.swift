//
//  AnnotatedSkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 5/3/23.
//

import SwiftUI

struct AnnotatedSkewtPlotView: View {
    @EnvironmentObject var store: Store<SkewtState>
    
    /// Current point of interest in 0.0...1.0
    @State var annotationPoint: CGPoint? = nil
    
    private let temperatureTickLength: CGFloat = 10.0
        
    private let windBarbContainerWidth: CGFloat = 20.0
    private let windBarbLength: CGFloat = 20.0
    
    private var shortenedAltitudeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.multiplier = 0.001
        return formatter
    }
    
    private var fullAltitudeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
    
    private var pressureAxisLabelFormatter: NumberFormatter {
        return NumberFormatter()
    }
    
    private var temperatureFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
    
    private var isobarAxisLabelFormatter: NumberFormatter {
        switch store.state.plotOptions.isobarTypes {
        case .none, .altitude:
            return shortenedAltitudeFormatter
        case .pressure:
            return pressureAxisLabelFormatter
        }
    }
    
    private var sounding: Sounding? {
        switch store.state.currentSoundingState.status {
        case .done(let sounding, _), .refreshing(let sounding):
            if !store.state.currentSoundingState.status.isStale {
                return sounding
            }
            
            fallthrough
        case .failed(_), .idle, .loading, .awaitingSoundingLocationData:
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
        guard store.state.plotOptions.showIsobarLabels,
                store.state.plotOptions.isobarTypes != .none else {
            return nil
        }
        
        let formatter = isobarAxisLabelFormatter
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
        let plot = plot

        ZStack {
            if case .loading = store.state.currentSoundingState.status {
                ProgressView().controlSize(.large)
            }
            
            Grid(horizontalSpacing: 0.0, verticalSpacing: 0.0) {
                GridRow {
                    yAxisLabelView(withPlot: plot)
                        .gridCellUnsizedAxes(.vertical)
                    
                    GeometryReader { geometry in
                        ZStack {
                            SkewtPlotView(plot: plot)
                                .environmentObject(store)
                                .aspectRatio(1.0, contentMode: .fit)
                                .border(.black)
                                .background {
                                    LinearGradient(
                                        colors: [Color("LowSkyBlue"), Color("HighSkyBlue")],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0.0)
                                        .onChanged {
                                            updateAnnotationPoint($0.location, geometryProxy: geometry)
                                        }
                                )
                            
                            annotations(
                                inBounds: CGRect(x: 0.0, y: 0.0, width: geometry.size.width, height: geometry.size.height),
                                fromPlot: plot
                            )
                            .clipped()
                        }
                    }
                    
                    windBarbView(withPlot: plot)
                        .gridCellUnsizedAxes(.vertical)
                }
                
                GridRow {
                    Rectangle()
                        .frame(width: yAxisLabelWidthOrNil ?? 0.0, height: xAxisLabelHeightOrNil ?? 0.0)
                        .foregroundColor(.clear)
                    
                    xAxisLabelView(withPlot: plot)
                        .gridCellUnsizedAxes(.horizontal)
                }
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
    
    @ViewBuilder
    private func annotations(inBounds bounds: CGRect, fromPlot plot: SkewtPlot) -> some View {
        if let annotationPoint = annotationPoint,
            let (temperatureData, dewPointData) = plot.closestTemperatureAndDewPointData(toY: annotationPoint.y) {
            
            let temperaturePoint = plot.point(pressure: temperatureData.pressure, temperature: temperatureData.temperature!)
            let dewPointPoint = plot.point(pressure: dewPointData.pressure, temperature: dewPointData.dewPoint!)
            
            let style = store.state.plotOptions.plotStyling
            
            temperatureTick(
                atNormalizedPoint: temperaturePoint,
                inRect: bounds,
                style: style.lineStyle(forType: .temperature)
            )
            
            temperatureTick(
                atNormalizedPoint: dewPointPoint,
                inRect: bounds,
                style: style.lineStyle(forType: .dewPoint)
            )
            
            let leftRoom = dewPointPoint.x * bounds.size.width
            let rightRoom = (1.0 - temperaturePoint.x) * bounds.size.width
            
            Group {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: leftRoom, height: 20)
                    .padding(.horizontal, -10)
                    .overlay {
                        HStack {
                            Text(altitudeDetailText(temperatureData))
                                .padding(2)
                                .background {
                                    RoundedRectangle(cornerRadius: 4)
                                        .foregroundColor(.white.opacity(0.75))
                                }
                            
                            
                            Spacer()
                            Text(temperatureFormatter.string(from: dewPointData.dewPoint! as NSNumber)! + "°")
                        }
                    }
                    .position(x: leftRoom / 2.0, y: dewPointPoint.y * bounds.size.height)
                
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: rightRoom, height: 20)
                    .padding(.horizontal, -10)
                    .overlay(alignment: .leading) {
                        Text(temperatureFormatter.string(from: temperatureData.temperature! as NSNumber)! + "°")
                    }
                    .position(x: bounds.size.width - (rightRoom / 2.0), y: temperaturePoint.y * bounds.size.height)
            }
            .font(Font(axisLabelFont))
            
        } else {
            EmptyView()
        }
    }
    
    private func altitudeDetailText(_ dataPoint: LevelDataPoint) -> String {
        switch store.state.plotOptions.isobarTypes {
        case .altitude, .none:
            return fullAltitudeFormatter.string(from: dataPoint.altitudeInFeet as NSNumber)! + "'"
            
        case .pressure:
            return isobarAxisLabelFormatter.string(from: dataPoint.pressure as NSNumber)! + "mb"
        }
    }
    
    private func updateAnnotationPoint(_ point: CGPoint, geometryProxy geometry: GeometryProxy) {
        annotationPoint = CGPoint(
            x: point.x / geometry.size.width,
            y: point.y / geometry.size.height
        )
    }
    
    @ViewBuilder
    private func temperatureTick(atNormalizedPoint normalizedPoint: CGPoint,
                                 inRect rect: CGRect,
                                 style: PlotOptions.PlotStyling.LineStyle) -> some View {
        let halfLength = temperatureTickLength / 2.0
        let point = CGPoint(
            x: normalizedPoint.x * rect.size.width + rect.origin.x,
            y: normalizedPoint.y * rect.size.height + rect.origin.y
        )
        
        Path() { path in
            path.move(to: CGPoint(x: point.x - halfLength, y: point.y))
            path.addLine(to: CGPoint(x: point.x + halfLength, y: point.y))
        }
        .applyLineStyle(style)
    }
    
    @ViewBuilder
    private func yAxisLabelView(withPlot plot: SkewtPlot) -> some View {
        if yAxisLabelWidthOrNil == nil {
            Rectangle()
                .foregroundColor(.clear)
                .frame(width: 0.0, height: 0.0)
        } else {
            Rectangle().frame(width: yAxisLabelWidthOrNil!).foregroundColor(.clear).overlay {
                GeometryReader { geometry in
                    let isobars = isobars(withPlot: plot)
                    
                    ForEach(isobars.keys.sorted().reversed(), id: \.self) { key in
                        Text(isobarAxisLabelFormatter.string(from: key as NSNumber) ?? "")
                            .font(Font(leftAxisLabelFont))
                            .lineLimit(1)
                            .foregroundColor(isobarColor)
                            .position(
                                x: geometry.size.width / 2.0,
                                y: yForIsobar(key, inPlot: plot) * geometry.size.height
                            )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func xAxisLabelView(withPlot plot: SkewtPlot) -> some View {
        if xAxisLabelHeightOrNil == nil {
            EmptyView()
        } else {
            Rectangle().frame(height: xAxisLabelHeightOrNil!).foregroundColor(.clear).overlay {
                GeometryReader { geometry in
                    if store.state.plotOptions.showIsothermLabels {
                        let isotherms = plot.isothermPaths
                        ForEach(isotherms.keys.sorted(), id: \.self) { temperature in
                            let x = plot.x(forSurfaceTemperature: temperature) * geometry.size.width
                            if x >= 0 {
                                Text(String(Int(temperature)))
                                    .font(Font(bottomAxisLabelFont))
                                    .foregroundColor(isothermColor)
                                    .position(
                                        x: x,
                                        y: geometry.size.height / 2.0
                                    )
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func windBarbView(withPlot plot: SkewtPlot) -> some View {
        if !store.state.plotOptions.showWindBarbs {
            EmptyView()
        } else {
            Rectangle()
                .frame(width: windBarbContainerWidth)
                .foregroundColor(.clear)
                .overlay {
                    if let sounding = plot.sounding {
                        GeometryReader { geometry in
                            let x = geometry.size.width / 2.0
                            let windData = sounding.data.filter { $0.windDirection != nil && $0.windSpeed != nil }
                            
                            ForEach(windData, id: \.self) {
                                let y = plot.y(forPressure: $0.pressure) * geometry.size.height
                                
                                if y >= 0.0 && y <= geometry.size.height {
                                    WindBarb(
                                        bearingInDegrees: $0.windDirection!,
                                        speed: $0.windSpeed!,
                                        length: windBarbLength,
                                        tickLength: windBarbLength * 0.3
                                    )
                                    .stroke(.red, lineWidth: 1.0)
                                    .position(x: x, y: y)
                                }
                            }
                        }
                    } else {
                        EmptyView()
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
