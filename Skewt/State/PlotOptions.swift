//
//  PlotOptions.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct PlotOptions: Codable {
    enum Action: Skewt.Action, Codable {
        case changeAltitudeRange(ClosedRange<Double>)
        case changeSkew(Double)
        case setShowSurfaceParcelByDefault(Bool)
        case setShowMovableParcel(Bool)
        case changeIsothermTypes(IsothermTypes)
        case changeIsobarTypes(IsobarTypes)
        case changeAdiabatTypes(AdiabatTypes)
        case setMixingLines(Bool)
        case setIsobarLabels(Bool)
        case setIsothermLabels(Bool)
        case setWindBarbs(Bool)
        case setShowAnimatedWind(Bool)
    }
    
    struct PlotStyling: Codable {
        enum Action: Skewt.Action, Codable {
            case resetAllToDefaults
            case setStyleToDefault(PlotType)
            case setStyle(PlotType, LineStyle)
        }
        
        enum PlotType: Codable, Equatable, CaseIterable, Identifiable {
            case temperature
            case dewPoint
            case parcel
            case isotherms
            case zeroIsotherm
            case altitudeIsobars
            case pressureIsobars
            case dryAdiabats
            case moistAdiabats
            case isohumes
            
            var id: Self { self }
        }
        
        struct LineStyle: Codable, Equatable {
            var lineWidth: CGFloat
            var color: String
            var opacity: CGFloat
            var dashed: Bool
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
        
    var altitudeRange: ClosedRange<Double>?
    var skew: Double
    var showSurfaceParcelByDefault: Bool
    var showMovableParcel: Bool
    var isothermTypes: IsothermTypes
    var isobarTypes: IsobarTypes
    var adiabatTypes: AdiabatTypes
    var showMixingLines: Bool
    var showIsobarLabels: Bool
    var showIsothermLabels: Bool
    var showWindBarbs: Bool
    var showAnimatedWind: Bool
    var plotStyling: PlotStyling
}

extension PlotOptions {
    init() {
        altitudeRange = nil
        skew = 1.0
        showSurfaceParcelByDefault = true
        showMovableParcel = true
        isothermTypes = .tens
        isobarTypes = .altitude
        adiabatTypes = .tens
        showMixingLines = false
        showIsobarLabels = true
        showIsothermLabels = true
        showWindBarbs = false
        showAnimatedWind = true
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
            case .changeSkew(let skew):
                options.skew = skew
            case .setShowSurfaceParcelByDefault(let showSurfaceParcel):
                options.showSurfaceParcelByDefault = showSurfaceParcel
            case .setShowMovableParcel(let showParcel):
                options.showMovableParcel = showParcel
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
            case .setWindBarbs(let showWindBarbs):
                options.showWindBarbs = showWindBarbs
            case .setShowAnimatedWind(let showAnimatedWind):
                options.showAnimatedWind = showAnimatedWind
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
        case .resetAllToDefaults:
            return PlotOptions.PlotStyling()
        case .setStyleToDefault(let type):
            var s = state
            var styles = s.lineStyles
            styles.removeValue(forKey: type)
            s.lineStyles = styles
            
            return s
        case .setStyle(let type, let style):
            var s = state
            s.lineStyles[type] = style
            return s
        }
    }
}
