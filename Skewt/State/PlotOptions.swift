//
//  PlotOptions.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct PlotOptions: Codable {
    struct PlotStyling: Codable {
        enum PlotType: Codable {
            case temperature
            case dewPoint
            case isotherms
            case zeroIsotherm
            case altitudeIsobars
            case pressureIsobars
            case dryAdiabats
            case moistAdiabats
        }
        
        struct LineStyle: Codable {
            let lineWidth: CGFloat
            let color: String
            let opacity: CGFloat
            let dashed: Bool
        }
        
        let lineStyles: [PlotType: LineStyle]
    }
    
    enum IsothermTypes: Codable {
        case none
        case tens
        case zeroOnly
    }
    
    enum IsobarTypes: Codable {
        case none
        case altitude
        case pressure
    }
    
    enum AdiabatTypes: Codable {
        case none
        case tens
    }
        
    let altitudeRange: Range<Double>?
    let isothermTypes: IsothermTypes
    let isobarTypes: IsobarTypes
    let adiabatTypes: AdiabatTypes
    let showMixingLines: Bool
    let showIsobarLabels: Bool
    let showIsothermLabels: Bool
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
    }
}
