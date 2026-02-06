//
//  ForecastModels.swift
//  Skewt
//
//  Created by Jason Neel on 2/4/26.
//

import Foundation

// Meta data on forecast models from https://open-meteo.com/en/docs/model-updates
extension SoundingSelection.ForecastModel {
    enum Region {
        case global
        case europe
        case northAmerica
        case asia
    }

    var temporalResolution: TimeInterval {
        switch self {

        case .automatic:
            return 1 * 60 * 60 // 1h

        case .iconSeamlessEps,
             .iconGlobalEps:
            return 1 * 60 * 60 // 1h

        case .iconEuEps,
             .iconD2Eps:
            return 15 * 60 // 15 min

        case .ukmoGlobalEnsemble20km:
            return 1 * 60 * 60 // 1h

        case .ukmoUkEnsemble2km:
            return 15 * 60 // 15 min

        case .ncepGefsSeamless,
             .ncepGefs025,
             .ncepGefs05,
             .ncepAigefs025:
            return 3 * 60 * 60 // 3h

        case .meteoswissIconCh1Ensemble,
             .meteoswissIconCh2Ensemble:
            return 1 * 60 * 60 // 1h

        case .ecmwfIfs025Ensemble,
             .ecmwfAifs025Ensemble:
            return 1 * 60 * 60 // 1h

        case .gemGlobalEnsemble:
            return 3 * 60 * 60 // 3h

        case .bomAccessGlobalEnsemble:
            return 1 * 60 * 60 // 1h
        }
    }

    var updateFrequency: TimeInterval {
        switch self {

        case .automatic:
            return 1 * 60 * 60 // 1h

        case .iconSeamlessEps,
             .iconGlobalEps,
             .iconEuEps,
             .iconD2Eps:
            return 6 * 60 * 60 // 6h

        case .ukmoGlobalEnsemble20km,
             .ukmoUkEnsemble2km:
            return 6 * 60 * 60 // 6h

        case .ncepGefsSeamless,
             .ncepGefs025,
             .ncepGefs05,
             .ncepAigefs025:
            return 6 * 60 * 60 // 6h

        case .meteoswissIconCh1Ensemble,
             .meteoswissIconCh2Ensemble:
            return 3 * 60 * 60 // 3h

        case .ecmwfIfs025Ensemble,
             .ecmwfAifs025Ensemble:
            return 6 * 60 * 60 // 6h

        case .gemGlobalEnsemble:
            return 12 * 60 * 60 // 12h

        case .bomAccessGlobalEnsemble:
            return 12 * 60 * 60 // 12h
        }
    }

    /// Primary coverage region
    var region: Region {
        switch self {

        case .automatic:
            return .global

        case .iconSeamlessEps,
             .iconGlobalEps:
            return .global

        case .iconEuEps,
             .iconD2Eps:
            return .europe

        case .ukmoGlobalEnsemble20km:
            return .global

        case .ukmoUkEnsemble2km:
            return .europe

        case .ncepGefsSeamless,
             .ncepGefs025,
             .ncepGefs05,
             .ncepAigefs025:
            return .northAmerica

        case .meteoswissIconCh1Ensemble,
             .meteoswissIconCh2Ensemble:
            return .europe

        case .ecmwfIfs025Ensemble,
             .ecmwfAifs025Ensemble:
            return .global

        case .gemGlobalEnsemble:
            return .global

        case .bomAccessGlobalEnsemble:
            return .asia
        }
    }
}
