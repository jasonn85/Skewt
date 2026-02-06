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
        case asia
    }

    var temporalResolution: TimeInterval {
        switch self {

        case .automatic:
            return 1 * 60 * 60

        // ICON
        case .iconSeamless, .iconGlobal,
             .iconSeamlessEps, .iconGlobalEps:
            return 1 * 60 * 60

        case .iconEu, .iconD2,
             .iconEuEps, .iconD2Eps:
            return 15 * 60

        // UKMO
        case .ukmoGlobal, .ukmoGlobalEnsemble20km:
            return 1 * 60 * 60

        case .ukmoUk, .ukmoUkEnsemble2km:
            return 15 * 60

        // GFS / GEFS
        case .gfsSeamless, .gfs025, .gfs05,
             .ncepGefsSeamless, .ncepGefs025,
             .ncepGefs05, .ncepAigefs025:
            return 3 * 60 * 60

        // MeteoSwiss
        case .meteoswissIconCh1, .meteoswissIconCh2,
             .meteoswissIconCh1Ensemble, .meteoswissIconCh2Ensemble:
            return 1 * 60 * 60

        // ECMWF
        case .ecmwfIfs025, .ecmwfAifs025,
             .ecmwfIfs025Ensemble, .ecmwfAifs025Ensemble:
            return 1 * 60 * 60

        // GEM
        case .gemGlobal, .gemGlobalEnsemble:
            return 3 * 60 * 60

        // BOM
        case .bomAccessGlobal, .bomAccessGlobalEnsemble:
            return 1 * 60 * 60
        }
    }

    var updateFrequency: TimeInterval {
        switch self {

        case .automatic:
            return 1 * 60 * 60

        // ICON / UKMO / ECMWF
        case .iconSeamless, .iconGlobal, .iconEu, .iconD2,
             .iconSeamlessEps, .iconGlobalEps, .iconEuEps, .iconD2Eps,
             .ukmoGlobal, .ukmoUk,
             .ukmoGlobalEnsemble20km, .ukmoUkEnsemble2km,
             .ecmwfIfs025, .ecmwfAifs025,
             .ecmwfIfs025Ensemble, .ecmwfAifs025Ensemble:
            return 6 * 60 * 60

        // GFS / GEFS
        case .gfsSeamless, .gfs025, .gfs05,
             .ncepGefsSeamless, .ncepGefs025,
             .ncepGefs05, .ncepAigefs025:
            return 6 * 60 * 60

        // MeteoSwiss
        case .meteoswissIconCh1, .meteoswissIconCh2,
             .meteoswissIconCh1Ensemble, .meteoswissIconCh2Ensemble:
            return 3 * 60 * 60

        // GEM / BOM
        case .gemGlobal, .gemGlobalEnsemble,
             .bomAccessGlobal, .bomAccessGlobalEnsemble:
            return 12 * 60 * 60
        }
    }

    /// Primary coverage region
    var region: Region {
        switch self {

        case .automatic:
            return .global

        // Global
        case .iconSeamless, .iconGlobal,
             .iconSeamlessEps, .iconGlobalEps,
             .ukmoGlobal, .ukmoGlobalEnsemble20km,
             .gfsSeamless, .gfs025, .gfs05,
             .ncepGefsSeamless, .ncepGefs025,
             .ncepGefs05, .ncepAigefs025,
             .ecmwfIfs025, .ecmwfAifs025,
             .ecmwfIfs025Ensemble, .ecmwfAifs025Ensemble,
             .gemGlobal, .gemGlobalEnsemble:
            return .global

        // Europe
        case .iconEu, .iconD2,
             .iconEuEps, .iconD2Eps,
             .ukmoUk, .ukmoUkEnsemble2km,
             .meteoswissIconCh1, .meteoswissIconCh2,
             .meteoswissIconCh1Ensemble, .meteoswissIconCh2Ensemble:
            return .europe

        // Asia / Pacific
        case .bomAccessGlobal, .bomAccessGlobalEnsemble:
            return .asia
        }
    }
    
    var description: String {
        switch self {

        case .automatic:
            return "Automatic"

        // MARK: ICON (DWD)
        case .iconSeamless:
            return "ICON Seamless"

        case .iconGlobal:
            return "ICON Global"

        case .iconEu:
            return "ICON Europe"

        case .iconD2:
            return "ICON-D2"

        case .iconSeamlessEps:
            return "ICON Seamless Ensemble"

        case .iconGlobalEps:
            return "ICON Global Ensemble"

        case .iconEuEps:
            return "ICON Europe Ensemble"

        case .iconD2Eps:
            return "ICON-D2 Ensemble"

        // MARK: UKMO
        case .ukmoGlobal:
            return "UK Met Office Global"

        case .ukmoUk:
            return "UK Met Office UK"

        case .ukmoGlobalEnsemble20km:
            return "UK Met Office Global Ensemble"

        case .ukmoUkEnsemble2km:
            return "UK Met Office UK Ensemble"

        // MARK: GFS / GEFS (NCEP)
        case .gfsSeamless:
            return "GFS Seamless"

        case .gfs025:
            return "GFS 0.25°"

        case .gfs05:
            return "GFS 0.5°"

        case .ncepGefsSeamless:
            return "GEFS Seamless Ensemble"

        case .ncepGefs025:
            return "GEFS 0.25° Ensemble"

        case .ncepGefs05:
            return "GEFS 0.5° Ensemble"

        case .ncepAigefs025:
            return "AI GEFS 0.25° Ensemble"

        // MARK: MeteoSwiss
        case .meteoswissIconCh1:
            return "MeteoSwiss ICON-CH1"

        case .meteoswissIconCh2:
            return "MeteoSwiss ICON-CH2"

        case .meteoswissIconCh1Ensemble:
            return "MeteoSwiss ICON-CH1 Ensemble"

        case .meteoswissIconCh2Ensemble:
            return "MeteoSwiss ICON-CH2 Ensemble"

        // MARK: ECMWF
        case .ecmwfIfs025:
            return "ECMWF IFS 0.25°"

        case .ecmwfAifs025:
            return "ECMWF AI-IFS 0.25°"

        case .ecmwfIfs025Ensemble:
            return "ECMWF IFS 0.25° Ensemble"

        case .ecmwfAifs025Ensemble:
            return "ECMWF AI-IFS 0.25° Ensemble"

        // MARK: GEM
        case .gemGlobal:
            return "GEM Global"

        case .gemGlobalEnsemble:
            return "GEM Global Ensemble"

        // MARK: BOM
        case .bomAccessGlobal:
            return "BOM ACCESS Global"

        case .bomAccessGlobalEnsemble:
            return "BOM ACCESS Global Ensemble"
        }
    }
}
