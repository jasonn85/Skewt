//
//  SoundingSelection.swift
//  Skewt
//
//  Created by Jason Neel on 2/17/26.
//

import Foundation

struct SoundingSelection: Codable, Hashable, Identifiable {
    let type: ModelType
    let location: Location
    let time: Time
    let dataAgeBeforeRefresh: TimeInterval
    
    enum Action: Skewt.Action {
        case selectModelType(ModelType, Time = .now)
        case selectLocation(Location, Time = .now)
        case selectTime(Time)
        case selectModelTypeAndLocation(ModelType?, Location?, Time = .now)
    }
    
    enum ModelType: Codable, Hashable, CaseIterable, Identifiable, Equatable {
        case forecast(ForecastModel)
        case sounding
        
        static var allCases: [ModelType] {
            [.sounding] + ForecastModel.allCases.map { .forecast($0) }
        }
        
        var id: String {
            switch self {
            case .sounding:
                return "sounding"
            case .forecast(let model):
                return "forecast-\(model.rawValue)"
            }
        }
    }
    
    enum ForecastModel: String, Codable, CaseIterable, Identifiable, Equatable {
        case automatic = "auto"

        // ICON (DWD)
        case iconSeamlessEps = "icon_seamless_eps"
        case iconGlobalEps = "icon_global_eps"
        case iconEuEps = "icon_eu_eps"
        case iconD2Eps = "icon_d2_eps"

        case iconSeamless = "icon_seamless"
        case iconGlobal = "icon_global"
        case iconEu = "icon_eu"
        case iconD2 = "icon_d2"

        // UKMO
        case ukmoGlobalEnsemble20km = "ukmo_global_ensemble_20km"
        case ukmoUkEnsemble2km = "ukmo_uk_ensemble_2km"

        case ukmoGlobal = "ukmo_global"
        case ukmoUk = "ukmo_uk"

        // NCEP
        case ncepGefsSeamless = "ncep_gefs_seamless"
        case ncepGefs025 = "ncep_gefs025"
        case ncepGefs05 = "ncep_gefs05"
        case ncepAigefs025 = "ncep_aigefs025"

        case gfsSeamless = "gfs_seamless"
        case gfs025 = "gfs025"
        case gfs05 = "gfs05"

        // MeteoSwiss
        case meteoswissIconCh1Ensemble = "meteoswiss_icon_ch1_ensemble"
        case meteoswissIconCh2Ensemble = "meteoswiss_icon_ch2_ensemble"

        case meteoswissIconCh1 = "meteoswiss_icon_ch1"
        case meteoswissIconCh2 = "meteoswiss_icon_ch2"

        // ECMWF
        case ecmwfIfs025Ensemble = "ecmwf_ifs025_ensemble"
        case ecmwfAifs025Ensemble = "ecmwf_aifs025_ensemble"

        case ecmwfIfs025 = "ecmwf_ifs025"
        case ecmwfAifs025 = "ecmwf_aifs025"

        // Others
        case gemGlobalEnsemble = "gem_global_ensemble"
        case gemGlobal = "gem_global"

        case bomAccessGlobalEnsemble = "bom_access_global_ensemble"
        case bomAccessGlobal = "bom_access_global"

        var id: Self { self }
    }
    
    enum Location: Codable, Hashable, Identifiable {
        case closest
        case point(latitude: Double, longitude: Double)
        case named(name: String, latitude: Double, longitude: Double)
        
        var id: Self { self }
    }
    
    enum Time: Codable, Hashable, Identifiable {
        case now
        case relative(TimeInterval)
        case numberOfSoundingsAgo(Int)  // .numberOfSoundingsAgo(0) is equivalent to .now
        case specific(Date)
        
        var id: Self { self }
    }
    
    var id: Self { self }
}

// Default initializer
extension SoundingSelection {
    init() {
        type = .forecast(.automatic)
        location = .closest
        time = .now

        dataAgeBeforeRefresh = SoundingSelection.defaultDataAgeBeforeRefresh(for: type)
    }
}

extension SoundingSelection {
    var requiresLocation: Bool {
        switch self.location {
        case .closest:
            return true
        default:
            return false
        }
    }
}

extension SoundingSelection {
    func isEqualIgnoringTime(to other: SoundingSelection) -> Bool {
        type == other.type && location == other.location
    }
}

extension Date {
    func soundingSelectionTime(forModelType modelType: SoundingSelection.ModelType, referenceDate: Date = .now) -> SoundingSelection.Time {
        let timeInterval = timeIntervalSince(referenceDate)

        switch modelType {
        case .forecast(_):
            return timeInterval == 0.0 ? .now : .relative(timeInterval)
        case .sounding:
            let intervalCount = Int(round(timeInterval / 60.0 / 60.0 / Double(modelType.hourInterval)))
            
            if intervalCount == 0 {
                return .now
            } else {
                return .numberOfSoundingsAgo(-intervalCount)
            }
        }
    }
}

extension SoundingSelection: CustomStringConvertible {
    var description: String {
        location.briefDescription
    }
}

extension SoundingSelection.Location {
    var briefDescription: String {
        switch self {
        case .closest:
            return "Current location"
        case .named(let name, _, _):
            return name
        case .point(latitude: let latitude, longitude: let longitude):
            return String(format: "%.0f, %.0f", latitude, longitude)
        }
    }
}

extension SoundingSelection {
    /// A wall clock time for the current selection, resolving any relative time
    var timeAsConcreteDate: Date {
        switch time {
        case .now:
            return Date.now
        case .relative(let interval):
            return Date.now.addingTimeInterval(interval)
        case .specific(let date):
            return date
        case .numberOfSoundingsAgo(let soundingsAgo):
            let interval = TimeInterval(soundingsAgo * type.hourInterval) * 60.0 * 60.0
            
            return Date.now.addingTimeInterval(-interval)
        }
    }
}

extension SoundingSelection.ModelType {
    var hourInterval: Int {
        switch self {
        case .forecast(_):
            return 1
        case .sounding:
            return 12
        }
    }
}

extension SoundingSelection {
    static func defaultDataAgeBeforeRefresh(for type: ModelType) -> TimeInterval {
        switch type {
        case .forecast:
            return TimeInterval(5.0 * 60.0)
        case .sounding:
            return TimeInterval(60.0 * 60.0)
        }
    }
}

// Reducer
extension SoundingSelection {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? Action else {
            return state
        }
        
        switch action {
        case .selectModelType(let type, let time):
            return SoundingSelection(
                type: type,
                location: state.location,
                time: time,
                dataAgeBeforeRefresh: SoundingSelection.defaultDataAgeBeforeRefresh(for: type)
            )
        case .selectLocation(let location, let time):
            return SoundingSelection(type: state.type, location: location, time: time, dataAgeBeforeRefresh: state.dataAgeBeforeRefresh)
        case .selectTime(let time):
            return SoundingSelection(type: state.type, location: state.location, time: time, dataAgeBeforeRefresh: state.dataAgeBeforeRefresh)
        case .selectModelTypeAndLocation(let type, let location, let time):
            let resolvedType = type ?? state.type
            let resolvedDataAge = type == nil ? state.dataAgeBeforeRefresh : SoundingSelection.defaultDataAgeBeforeRefresh(for: resolvedType)
            return SoundingSelection(
                type: resolvedType,
                location: location ?? state.location,
                time: time,
                dataAgeBeforeRefresh: resolvedDataAge
            )
        }
    }
}

extension SoundingSelection.Action {
    // Is this action changing the sounding type or location?
    var isCreatingNewSelection: Bool {
        switch self {
        case .selectModelTypeAndLocation(let type, let location, _):
            return type != nil || location != nil
        case .selectLocation(_, _), .selectModelType(_, _):
            return true
        case .selectTime(_):
            // Just changing time is not creating a new selection type
            return false
        }
    }
}
