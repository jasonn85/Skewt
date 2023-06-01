//
//  PlotOptions.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct PlotOptions: Codable {
    enum Action: Skewt.Action, Codable {
        case changeAltitudeRange(Range<Double>)
        case changeIsothermTypes(IsothermTypes)
        case changeIsobarTypes(IsobarTypes)
        case changeAdiabatTypes(AdiabatTypes)
        case setMixingLines(Bool)
        case setIsobarLabels(Bool)
        case setIsothermLabels(Bool)
    }
    
    struct PlotStyling: Codable {
        enum Action: Skewt.Action, Codable {
            case resetToDefaults
            case setLineStyle(PlotType, LineStyle)
        }
        
        enum PlotType: Codable, Equatable, CaseIterable, Identifiable {
            case temperature
            case dewPoint
            case isotherms
            case zeroIsotherm
            case altitudeIsobars
            case pressureIsobars
            case dryAdiabats
            case moistAdiabats
            
            var id: Self { self }
        }
        
        struct LineStyle: Codable, Equatable {
            let lineWidth: CGFloat
            let color: String
            let opacity: CGFloat
            let dashed: Bool
        }
        
        var lineStyles: [PlotType: LineStyle]
    }
    
    enum IsothermTypes: Codable, Equatable, CaseIterable, Identifiable {
        case none
        case zeroOnly
        case tens
        
        var id: Self { self }
    }
    
    enum IsobarTypes: Codable, Equatable, CaseIterable, Identifiable {
        case none
        case altitude
        case pressure
        
        var id: Self { self }
    }
    
    enum AdiabatTypes: Codable, Equatable, CaseIterable, Identifiable {
        case none
        case tens
        
        var id: Self { self }
    }
        
    var altitudeRange: Range<Double>?
    var isothermTypes: IsothermTypes
    var isobarTypes: IsobarTypes
    var adiabatTypes: AdiabatTypes
    var showMixingLines: Bool
    var showIsobarLabels: Bool
    var showIsothermLabels: Bool
    var plotStyling: PlotStyling
}

extension PlotOptions {
    init() {
        altitudeRange = nil
        isothermTypes = .tens
        isobarTypes = .altitude
        adiabatTypes = .tens
        showMixingLines = false
        showIsobarLabels = true
        showIsothermLabels = true
        plotStyling = PlotStyling()
    }
}

extension PlotOptions.PlotStyling {
    init() {
        lineStyles = [:]
    }
}

extension PlotOptions {
    static let reducer: Reducer<Self> = { state, action in
        var options = state
        options.plotStyling = PlotStyling.reducer(options.plotStyling, action)
        
        if let action = action as? PlotOptions.Action {
            switch action  {
            case .changeAltitudeRange(let range):
                options.altitudeRange = range
            case .changeIsothermTypes(let types):
                options.isothermTypes = types
            case .changeIsobarTypes(let types):
                options.isobarTypes = types
            case .changeAdiabatTypes(let types):
                options.adiabatTypes = types
            case .setMixingLines(let mixingLines):
                options.showMixingLines = mixingLines
            case .setIsobarLabels(let isobarLabels):
                options.showIsobarLabels = isobarLabels
            case .setIsothermLabels(let isothermLabels):
                options.showIsothermLabels = isothermLabels
            }
        }
        
        return options
    }
}

extension PlotOptions.PlotStyling {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? PlotOptions.PlotStyling.Action else {
            return state
        }
        
        switch action {
        case .resetToDefaults:
            return PlotOptions.PlotStyling()
        case .setLineStyle(let type, let style):
            var s = state
            s.lineStyles[type] = style
            return s
        }
    }
}
