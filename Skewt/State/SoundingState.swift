//
//  SoundingState.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct SoundingSelection: Codable, Equatable {
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
    
    enum Location: Codable, Equatable {
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
        case pinSelection(SoundingSelection)
        case unpinSelection(SoundingSelection)
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
    var pinnedSelections: [SoundingSelection]
    var recentSelections: [SoundingSelection]
    var status: Status
}

// Default initializer
extension SoundingState {
    init() {
        selection = SoundingSelection()
        pinnedSelections = []
        recentSelections = [selection]
        status = .idle
    }
    
    init(selection: SoundingSelection?) {
        self.selection = selection ?? SoundingSelection()
        pinnedSelections = []
        recentSelections = [self.selection]
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
        case .pinSelection(let selection):
            return "Pinning selection: \(selection)"
        case .unpinSelection(let selection):
            return "Unpinning selection: \(selection)"
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
        case .pinSelection(let selection):
            var state = state
            state.pinnedSelections = state.pinnedSelections.addingToHead(selection)
            
            return state
        case .unpinSelection(let selection):
            var state = state
            state.pinnedSelections = state.pinnedSelections.filter { $0 != selection }
            
            return state
        case .changeAndLoadSelection(let action):
            let selection = SoundingSelection.reducer(state.selection, action)
            var recentSelections = state.recentSelections
            
            if action.isCreatingNewSelection {
                let maximumRecents = 5
                recentSelections = recentSelections.addingToHead(selection, maximumCount: maximumRecents)
            }
            
            return SoundingState(
                selection: selection,
                pinnedSelections: state.pinnedSelections,
                recentSelections: recentSelections,
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

extension Array where Element: Equatable {
    public func addingToHead(_ element: Element, maximumCount: Int? = nil) -> Self {
        let max = maximumCount ?? self.count + 1
        
        return [element] + self.filter({ $0 != element })[0..<(max - 1)]
    }
}

extension Action {
    // Is this action changing the sounding type or location?
    var isCreatingNewSelection: Bool {
        switch self as? SoundingState.Action {
        case .changeAndLoadSelection(let action):
            switch action {
            case .selectLocation(_), .selectModelType(_):
                return true
            case .selectTime(_):
                // Just changing time is not creating a new selection type
                return false
            }
        default:
            return false
        }
    }
}
