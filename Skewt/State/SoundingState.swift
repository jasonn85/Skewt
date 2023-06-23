//
//  SoundingState.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct SoundingSelection: Codable, Hashable, Identifiable {
    enum Action: Skewt.Action {
        case selectModelType(ModelType)
        case selectLocation(Location)
        case selectTime(Time)
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
        case .loading, .refreshing(_):
            return true
        case .idle, .done(_), .failed(_):
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
            case .done(let sounding):
                state.status = .refreshing(sounding)
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
            state.status = .done(sounding)
            
            return state
        }
    }
}

extension SoundingSelection.Action {
    // Is this action changing the sounding type or location?
    var isCreatingNewSelection: Bool {
        switch self {
        case .selectLocation(_), .selectModelType(_):
            return true
        case .selectTime(_):
            // Just changing time is not creating a new selection type
            return false
        }
    }
}
