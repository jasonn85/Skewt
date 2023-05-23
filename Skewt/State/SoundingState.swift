//
//  SoundingState.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct SoundingSelection: Codable {
    enum Action: Skewt.Action {
        case selectModelType(ModelType)
        case selectLocation(Location)
        case selectTime(Time)
    }
    
    enum ModelType: Codable {
        case op40
        case raob
    }
    
    enum Location: Codable {
        case closest
        case point(latitude: Double, longitude: Double)
        case named(String)
    }
    
    enum Time: Codable, Equatable {
        case now
        case relative(TimeInterval)
        case specific(Date)
    }
    
    let type: ModelType
    let location: Location
    let time: Time
}

// Default initializer
extension SoundingSelection {
    init() {
        type = .op40
        location = .closest
        time = .now
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

// Reducer
extension SoundingSelection {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? Action else {
            return state
        }
        
        switch action {
        case .selectModelType(let type):
            return SoundingSelection(type: type, location: state.location, time: state.time)
        case .selectLocation(let location):
            return SoundingSelection(type: state.type, location: location, time: state.time)
        case .selectTime(let time):
            return SoundingSelection(type: state.type, location: state.location, time: time)
        }
    }
}

struct SoundingState: Codable {
    enum SoundingError: Error, Codable {
        case unableToGenerateRequestFromSelection
        case unparseableResponse
        case requestFailed
        case lackingLocationPermission  // We can't do closest weather if we lack CL permission
    }
    
    enum Action: Skewt.Action {
        case doRefresh
        case changeAndLoadSelection(SoundingSelection.Action)
        case didReceiveFailure(SoundingError)
        case didReceiveResponse(Sounding)
    }
    
    enum Status: Codable {
        case idle
        case loading
        case done(Sounding)
        case refreshing(Sounding)
        case failed(SoundingError)
    }
    
    let selection: SoundingSelection
    let status: Status
}

// Default initializer
extension SoundingState {
    init() {
        selection = SoundingSelection()
        status = .idle
    }
}

extension SoundingState.Status {
    var isLoading: Bool {
        switch self {
        case .loading, .refreshing(_):
            return true
        case .idle, .done(_), .failed(_):
            return false
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
            switch state.status {
            case .done(let sounding):
                return SoundingState(selection: state.selection, status: .refreshing(sounding))
            default:
                return SoundingState(selection: state.selection, status: .loading)
            }
            
        case .changeAndLoadSelection(let action):
            return SoundingState(selection: SoundingSelection.reducer(state.selection, action),
                                 status: .loading)
            
        case .didReceiveFailure(let error):
            return SoundingState(selection: state.selection, status: .failed(error))
        case .didReceiveResponse(let sounding):
            return SoundingState(selection: state.selection, status: .done(sounding))
        }
    }
}
