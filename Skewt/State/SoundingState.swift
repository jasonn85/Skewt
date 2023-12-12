//
//  SoundingState.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct SoundingSelection: Codable, Hashable, Identifiable {
    enum Action: Skewt.Action {
        case selectModelType(ModelType, Time = .now)
        case selectLocation(Location, Time = .now)
        case selectTime(Time)
        case selectModelTypeAndLocation(ModelType?, Location?, Time = .now)
    }
    
    enum ModelType: Codable, CaseIterable, Identifiable, Equatable {
        case op40
        case raob
        
        var id: Self { self }
    }
    
    enum Location: Codable, Hashable, Identifiable {
        case closest
        case point(latitude: Double, longitude: Double)
        case named(String)
        
        var id: Self { self }
    }
    
    enum Time: Codable, Hashable, Identifiable {
        case now
        case relative(TimeInterval)
        case numberOfSoundingsAgo(Int)  // .numberOfSoundingsAgo(1) is equivalent to .now
        case specific(Date)
        
        var id: Self { self }
    }
    
    let type: ModelType
    let location: Location
    let time: Time
    
    var id: Self { self }
}

// Default initializer
extension SoundingSelection {
    init() {
        type = .op40
        location = .closest
        time = .now
    }
}

extension SoundingSelection.Location {
    var nameOrNil: String? {
        switch self {
        case .named(let name):
            return name
        case .closest, .point(_, _):
            return nil
        }
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
        case .op40:
            return timeInterval == 0.0 ? .now : .relative(timeInterval)
        case .raob:
            let intervalCount = Int(round(timeInterval / 60.0 / 60.0 / Double(modelType.hourInterval)))
            
            if abs(intervalCount) <= 1 {
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

extension SoundingSelection.ModelType {
    var hourInterval: Int {
        switch self {
        case .op40:
            return 1
//        case .nam:
//            return 3
//        case .gfs:
//            return 3
        case .raob:
            return 12
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
            return SoundingSelection(type: type, location: state.location, time: time)
        case .selectLocation(let location, let time):
            return SoundingSelection(type: state.type, location: location, time: time)
        case .selectTime(let time):
            return SoundingSelection(type: state.type, location: state.location, time: time)
        case .selectModelTypeAndLocation(let type, let location, let time):
            return SoundingSelection(
                type: type ?? state.type,
                location: location ?? state.location,
                time: time
            )
        }
    }
}

struct SoundingState: Codable {
    enum SoundingError: Error, Codable {
        case unableToGenerateRequestFromSelection
        case emptyResponse
        case unparseableResponse
        case requestFailed
        case lackingLocationPermission  // We can't do closest weather if we lack CL permission
    }
    
    enum Action: Skewt.Action {
        case doRefresh
        case changeAndLoadSelection(SoundingSelection.Action)
        case didReceiveFailure(SoundingError)
        case didReceiveResponse(Sounding)
        case awaitSoundingLocation
    }
    
    enum Status: Codable {
        case idle
        case awaitingSoundingLocationData
        case loading
        case done(Sounding, Date)
        case refreshing(Sounding)
        case failed(SoundingError)
    }
    
    var selection: SoundingSelection
    var status: Status
}

// Default initializer
extension SoundingState {
    init() {
        selection = SoundingSelection()
        status = .idle
    }
    
    init(selection: SoundingSelection?) {
        self.selection = selection ?? SoundingSelection()
        status = .idle
    }
}

extension SoundingState.Status {
    var isLoading: Bool {
        switch self {
        case .loading, .refreshing(_), .awaitingSoundingLocationData:
            return true
        case .idle, .done(_, _), .failed(_):
            return false
        }
	}
    
    private var staleAge: TimeInterval { 60.0 * 60.0 }  // one hour
    
    /// Was this data fetched so long ago that it's likely out of date?
    var isStale: Bool {
        switch self {
        case .done(_, let fetchDate):
            return -fetchDate.timeIntervalSinceNow >= staleAge
        case .idle, .awaitingSoundingLocationData, .loading, .refreshing(_), .failed(_):
            return false
        }
    }
}

extension SoundingState.Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .doRefresh:
            return "Refreshing"
        case .changeAndLoadSelection(let selection):
            return "Changing selection and reloading: \(selection)"
        case .didReceiveFailure(let error):
            return "Failed to load sounding: \(error)"
        case .didReceiveResponse(let sounding):
            return "Received sounding with \(sounding.data.count) data points"
        case .awaitSoundingLocation:
            return "Waiting for sounding location data"
        }
    }
}

// Reducer
extension SoundingState {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? Action else {
            return state
        }
        
        switch action {
        case .doRefresh:
            var state = state
            
            switch state.status {
            case .done(let sounding, _):
                if state.status.isStale {
                    state.status = .loading
                } else {
                    state.status = .refreshing(sounding)
                }
            default:
                state.status = .loading
            }
            
            return state
        case .changeAndLoadSelection(let action):
            return SoundingState(
                selection: SoundingSelection.reducer(state.selection, action),
                status: .loading
            )
        case .didReceiveFailure(let error):
            var state = state
            state.status = .failed(error)
            
            return state
        case .didReceiveResponse(let sounding):
            var state = state
            state.status = .done(sounding, .now)
            
            return state
        case .awaitSoundingLocation:
            var state = state
            state.status = .awaitingSoundingLocationData
            
            return state
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
