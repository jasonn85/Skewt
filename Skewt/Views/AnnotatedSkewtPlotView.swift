//
//  AnnotatedSkewtPlotView.swift
//  Skewt
//
//  Created by Jason Neel on 5/3/23.
//

import SwiftUI

struct PlotSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let newValue = nextValue()
        
        if newValue != .zero {
            value = newValue
        }
    }
}

struct AnnotatedSkewtPlotView: View {
    let soundingState: SoundingState
    let plotOptions: PlotOptions
    
    @State var annotationPoint: UnitPoint? = nil
    
    @State var zoom: CGFloat = 1.0
    @State var zoomAnchor: UnitPoint = .center
    
    private var zoomedSquare: ZoomedSquare {
        try! ZoomedSquare(zoom: zoom, anchor: zoomAnchor)
    }
    
    @State private var plotSize: CGSize = .zero
    
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
        switch plotOptions.isobarTypes {
        case .none, .altitude:
            return shortenedAltitudeFormatter
        case .pressure:
            return pressureAxisLabelFormatter
        }
    }
    
    private var sounding: Sounding? {
        soundingState.sounding
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
        guard plotOptions.showIsobarLabels,
                plotOptions.isobarTypes != .none else {
            return nil
        }
        
        let formatter = isobarAxisLabelFormatter
        let sampleAltitudes = [0.0, 5_000.0, 10_000.0, 20_000.0,
                               30_000.0, 40_000.0]
        let samplePressures = [0.0, 1050.0, 9999.0, 8888.0]
        var widest: CGFloat = 0.0
        var samples: [Double]
        
        switch plotOptions.isobarTypes {
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
        guard plotOptions.showIsothermLabels else {
            return nil
        }
        
        let text = "12334567890"
        let attributes = [NSAttributedString.Key.font: bottomAxisLabelFont]
        return text.size(withAttributes: attributes).height
    }
    
    var body: some View {
        let plot = plot

        ZStack {
            if case .loading = soundingState.status {
                ProgressView().controlSize(.large)
            }
            
            Grid(horizontalSpacing: 0.0, verticalSpacing: 0.0) {
                GridRow {
                    yAxisLabelView(withPlot: plot)
                        .gridCellUnsizedAxes(.vertical)
                    
                    ZStack {
                        SkewtPlotView(plotOptions: plotOptions, plot: plot, parcelPoint: annotationPointAsCGPoint)
                            .aspectRatio(1.0, contentMode: .fit)
                            .scaleEffect(zoom, anchor: zoomAnchor)
                            .border(.black)
                            .clipped()
                            .overlay {
                                GeometryReader { geometry in
                                    ZStack {
                                        TouchCatchView(
                                            annotationPoint: $annotationPoint,
                                            zoom: $zoom,
                                            zoomAnchor: $zoomAnchor,
                                            bounceBackAnimation: .easeOut(duration: 0.2)
                                        )

                                        Rectangle()
                                            .foregroundColor(.clear)
                                            .preference(key: PlotSizePreferenceKey.self, value: geometry.size)
                                            .overlay {
                                                annotations(
                                                    inBounds: CGRect(origin: .zero, size: plotSize),
                                                    fromPlot: plot
                                                )
                                                .clipped()
                                            }
                                    }
                                }
                            }
                            .background {
                                GeometryReader { geometry in
                                    let winds = plotOptions.showAnimatedWind ? 
                                    sounding?.data.reducedWindData(sounding!.data.maximumWindReducer()).reduce(into: [Double:Double]()) {
                                            $0[plot.y(forPressure: $1.pressure)] = $1.windMagnitude
                                        } 
                                    : nil
                                    
                                    BackgroundView(
                                        frame: CGRect(origin: .zero, size: geometry.size),
                                        winds: winds
                                    )
                                    .scaleEffect(zoom, anchor: zoomAnchor)
                                    .clipped()
                                }
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
        .onPreferenceChange(PlotSizePreferenceKey.self) { preference in
            withAnimation {
                self.plotSize = preference
            }
        }
    }
    
    @ViewBuilder
    private func annotations(inBounds bounds: CGRect, fromPlot plot: SkewtPlot) -> some View {
        if let annotationPoint = annotationPoint,
            let (temperatureData, dewPointData) = plot.closestTemperatureAndDewPointData(toY: annotationPoint.y) {
            
            let unzoomedTemperaturePoint = plot.point(pressure: temperatureData.pressure, temperature: temperatureData.temperature!)
            let temperaturePoint = zoomedSquare.visiblePointForActualPoint(
                UnitPoint(x: unzoomedTemperaturePoint.x, y: unzoomedTemperaturePoint.y)
            )
            let unzoomedDewPointPoint = plot.point(pressure: dewPointData.pressure, temperature: dewPointData.dewPoint!)
            let dewPointPoint = zoomedSquare.visiblePointForActualPoint(
                UnitPoint(x: unzoomedDewPointPoint.x, y: unzoomedDewPointPoint.y)
            )
            
            let style = plotOptions.plotStyling
            
            temperatureTick(
                atNormalizedPoint: CGPoint(x: temperaturePoint.x, y: temperaturePoint.y),
                inRect: bounds,
                style: style.lineStyle(forType: .temperature)
            )
            
            temperatureTick(
                atNormalizedPoint: CGPoint(x: dewPointPoint.x, y: dewPointPoint.y),
                inRect: bounds,
                style: style.lineStyle(forType: .dewPoint)
            )
            
            let minimumLeftRoom = 120.0 / bounds.size.width
            let minimumRightRoom = 90.0 / bounds.size.width
            let leftRoom = (
                dewPointPoint.x >= minimumLeftRoom
                ? dewPointPoint.x * bounds.size.width
                : minimumLeftRoom * bounds.size.width
            )
            let rightRoom = (
                (1.0 - temperaturePoint.x) >= minimumRightRoom 
                ? (1.0 - temperaturePoint.x) * bounds.size.width
                : minimumRightRoom * bounds.size.width
            )
            
            Group {
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: leftRoom, height: 20)
                    .padding(.horizontal, -10)
                    .overlay {
                        HStack {
                            Text(altitudeDetailText(temperatureData))
                                .annotationFraming()
                                .foregroundColor(isobarColor)
                            
                            Spacer()
                            
                            Text(temperatureFormatter.string(from: dewPointData.dewPoint! as NSNumber)! + "°")
                                .annotationFraming()
                                .foregroundColor(dewPointColor)
                        }
                    }
                    .position(x: leftRoom / 2.0, y: dewPointPoint.y * bounds.size.height)
                
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: rightRoom, height: 20)
                    .padding(.horizontal, -10)
                    .overlay(alignment: .leading) {
                        HStack {
                            Text(temperatureFormatter.string(from: temperatureData.temperature! as NSNumber)! + "°")
                                .annotationFraming()
                                .foregroundColor(temperatureColor)
                            
                            Spacer()
                            
                            Image(systemName: "xmark.circle.fill")
                                .annotationFraming()
                                .foregroundColor(.gray)
                                .onTapGesture {
                                    self.annotationPoint = nil
                                }
                        }
                    }
                    .position(x: bounds.size.width - (rightRoom / 2.0), y: temperaturePoint.y * bounds.size.height)
            }
            .font(Font(axisLabelFont))
            
        } else {
            EmptyView()
        }
    }
    
    private func altitudeDetailText(_ dataPoint: SoundingData.Point) -> String {
        switch plotOptions.isobarTypes {
        case .altitude, .none:
            return fullAltitudeFormatter.string(from: dataPoint.altitudeInFeet as NSNumber)! + "'"
            
        case .pressure:
            return isobarAxisLabelFormatter.string(from: dataPoint.pressure as NSNumber)! + "mb"
        }
    }
    
    private func updateAnnotationPoint(_ point: CGPoint) {
        annotationPoint = UnitPoint(
            x: point.x / plotSize.width,
            y: point.y / plotSize.height
        )
    }
    
    @ViewBuilder
    private func temperatureTick(atNormalizedPoint normalizedPoint: CGPoint,
                                 inRect rect: CGRect,
                                 style: PlotOptions.PlotStyling.LineStyle) -> some View {
        let halfLength = temperatureTickLength / 2.0
        let point = CGPoint(
            x: normalizedPoint.x * plotSize.width + rect.origin.x,
            y: normalizedPoint.y * plotSize.height + rect.origin.y
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
            Rectangle()
                .frame(width: yAxisLabelWidthOrNil!)
                .foregroundColor(.clear)
                .overlay {
                    GeometryReader { geometry in
                        let isobars = isobars(withPlot: plot)
                        
                        ForEach(isobars.keys.sorted().reversed(), id: \.self) { key in
                            let unitPoint = zoomedSquare.visiblePointForActualPoint(UnitPoint(x: 0.0, y: yForIsobar(key, inPlot: plot)))
                            let y = unitPoint.y * plotSize.height
                            
                            if y >= 0.0 && y < plotSize.height {
                                Text(isobarAxisLabelFormatter.string(from: key as NSNumber) ?? "")
                                    .font(Font(leftAxisLabelFont))
                                    .lineLimit(1)
                                    .foregroundColor(isobarColor)
                                    .position(
                                        x: geometry.size.width / 2.0,
                                        y: y
                                    )
                            }
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
            Rectangle()
                .frame(height: xAxisLabelHeightOrNil!)
                .foregroundColor(.clear)
                .overlay {
                    GeometryReader { geometry in
                        if plotOptions.showIsothermLabels {
                            let isotherms = plot.isothermPaths
                            let bottom = zoomedSquare.visibleRect.maxY
                            
                            ForEach(isotherms.keys.sorted(), id: \.self) { temperature in
                                let unzoomedX = plot.x(forIsotherm: temperature, atY: bottom)
                                let normalizedPoint = UnitPoint(x: unzoomedX, y: bottom)
                                let x = zoomedSquare.visiblePointForActualPoint(normalizedPoint).x * plotSize.width
                                
                                if x >= 0 && x < plotSize.width {
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
        if !plotOptions.showWindBarbs {
            EmptyView()
        } else {
            Rectangle()
                .frame(width: windBarbContainerWidth)
                .foregroundColor(.clear)
                .overlay {
                    if let sounding = plot.sounding {
                        GeometryReader { geometry in
                            let x = geometry.size.width / 2.0
                            let windData = sounding.data.dataPoints.filter { $0.windDirection != nil && $0.windSpeed != nil }
                            
                            ForEach(windData, id: \.self) {
                                let unzoomedNormalizedY = plot.y(forPressure: $0.pressure)
                                let normalizedY = zoomedSquare.visiblePointForActualPoint(UnitPoint(x: 0.0, y: unzoomedNormalizedY)).y
                                let y = normalizedY * plotSize.height
                                
                                if y >= 0.0 && y <= geometry.size.height {
                                    WindBarb(
                                        bearingInDegrees: $0.windDirection!,
                                        speed: $0.windSpeed!,
                                        length: windBarbLength,
                                        tickLength: windBarbLength * 0.3
                                    )
                                    .stroke(.red, lineWidth: 1.0)
                                    .fill($0.windSpeed! >= 5 ? .red : .clear)
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
        switch plotOptions.isobarTypes {
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
            plotOptions.isobarTypes == .pressure
            ? PlotOptions.PlotStyling.PlotType.pressureIsobars
            : .altitudeIsobars
        )
        
        return Color(cgColor: plotOptions.plotStyling.lineStyle(forType: type).cgColor)
    }
    
    private var isothermColor: Color {
        temperatureColor
    }
    
    private var temperatureColor: Color {
        Color(cgColor: plotOptions.plotStyling.lineStyle(forType: .temperature).cgColor)
    }
    
    private var dewPointColor: Color {
        Color(cgColor: plotOptions.plotStyling.lineStyle(forType: .dewPoint).cgColor)
    }
    
    private func yForIsobar(_ value: Double, inPlot plot: SkewtPlot) -> CGFloat {
        switch plotOptions.isobarTypes {
        case .none, .altitude:
            return plot.y(forPressureAltitude: value)
        case .pressure:
            return plot.y(forPressure: value)
        }
    }
    
    private var plot: SkewtPlot {
        var plot = SkewtPlot(sounding: sounding)
        plot.skew = plotOptions.skew
        
        if let altitudeRange = plotOptions.altitudeRange {
            plot.altitudeRange = altitudeRange
        }
        
        return plot
    }
    
    private var annotationPointAsCGPoint: CGPoint? {
        if let annotationPoint = annotationPoint {
            return CGPoint(x: annotationPoint.x, y: annotationPoint.y)
        }
        
        return nil
    }
}

struct AnnotationFraming: ViewModifier {
    var padding: CGFloat = 3.0
    var backgroundColor: Color = .white.opacity(0.75)
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .foregroundColor(backgroundColor)
            }
    }
}

extension View {
    func annotationFraming(padding: CGFloat? = nil, backgroundColor: Color? = nil) -> some View {
        var framing = AnnotationFraming()
        
        if let padding = padding {
            framing.padding = padding
        }
        
        if let backgroundColor = backgroundColor {
            framing.backgroundColor = backgroundColor
        }
        
        return self.modifier(framing)
    }
}

struct AnnotatedSkewtPlotView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore
        let _ = store.dispatch(PlotOptions.Action.setWindBarbs(true))
        
        AnnotatedSkewtPlotView(soundingState: store.state.currentSoundingState, plotOptions: store.state.plotOptions)
    }
}
