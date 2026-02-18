//
//  SoundingState.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation

struct SoundingState: Codable, Equatable {
    var selection: SoundingSelection
    var status: Status
    
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
        case didReceiveResponse(OpenMeteoSoundingList)
    }
    
    enum Status: Codable, Equatable {
        case idle
        case loading
        case done(OpenMeteoSoundingList)
        case refreshing(OpenMeteoSoundingList)
        case failed(SoundingError)
    }
    
    var sounding: Sounding? {
        switch status {
        case .idle, .loading, .failed(_):
            return nil
        case .done(let soundingList), .refreshing(let soundingList):
            switch selection.time {
            case .now:
                return soundingList.closestSounding()
            case .relative(let interval):
                return soundingList.closestSounding(toDate: .now.addingTimeInterval(interval))
            case .specific(let date):
                return soundingList.closestSounding(toDate: date)
            case.numberOfSoundingsAgo(let agoCount):
                let secondsAgo = Double(agoCount) * Double(selection.type.hourInterval) * 60.0 * 60.0
                return soundingList.closestSounding(toDate: .now.addingTimeInterval(-secondsAgo))
            }
        }
    }
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
        case .didReceiveResponse(let soundingList):
            return "Received list of \(soundingList.data.count) sounding\(soundingList.data.count != 1 ? "s" : "")"
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
            case .done(let soundingList):
                if Date.now.timeIntervalSince(soundingList.fetchTime) > state.selection.dataAgeBeforeRefresh {
                    state.status = .loading
                } else {
                    state.status = .refreshing(soundingList)
                }
            default:
                state.status = .loading
            }
            
            return state
        case .changeAndLoadSelection(let action):
            // Try to find data for the new selection already existing in our data. We'll return a .done state
            //  if that succeeds. If not, we'll return a .loading at the bottom of this case.
            
            // Is our data stale?
            if let openMeteoSounding = state.sounding as? OpenMeteoSounding,
               Date.now.timeIntervalSince(openMeteoSounding.fetchTime) < state.selection.dataAgeBeforeRefresh {
                // Our data is not stale. Now is the selection just a time change or no change at all?
                switch state.status {
                case .done(let soundingList):
                    switch action {
                    case .selectLocation(state.selection.location, state.selection.time),
                            .selectModelType(state.selection.type, state.selection.time):
                        return SoundingState(selection: state.selection, status: .done(soundingList))
                        
                    case .selectTime(let time),
                            .selectModelTypeAndLocation(nil, nil, let time),
                            .selectModelTypeAndLocation(state.selection.type, nil, let time),
                            .selectModelTypeAndLocation(nil, state.selection.location, let time),
                            .selectModelTypeAndLocation(state.selection.type, state.selection.location, let time):
                        // It is just a time change. Do we have data for that time already?
                        let date: Date
                        
                        switch time {
                        case .now:
                            date = .now
                        case .numberOfSoundingsAgo(let countAgo):
                            let intervalAgo = Double(countAgo) * Double(state.selection.type.hourInterval) * 60.0 * 60.0
                            date = .now.addingTimeInterval(-intervalAgo)
                        case .relative(let interval):
                            date = .now.addingTimeInterval(interval)
                        case .specific(let specificDate):
                            date = specificDate
                        }
                        
                        if let closestTime = soundingList.closestSounding(toDate: date)?.date,
                           abs(closestTime.timeIntervalSince(date)) <= Double(state.selection.type.hourInterval) * 60.0 * 60.0 {
                            // No loading needed! Hooray!
                            return SoundingState(selection:
                                                    SoundingSelection(
                                                        type: state.selection.type,
                                                        location: state.selection.location,
                                                        time: time,
                                                        dataAgeBeforeRefresh: state.selection.dataAgeBeforeRefresh
                                                    ),
                                                 status: .done(soundingList)
                            )
                        }
                    default:
                        break
                    }
                default:
                    break
                }
            }
            
            // Load data for the new selection or stale data.
            return SoundingState(
                selection: SoundingSelection.reducer(state.selection, action),
                status: .loading
            )
        case .didReceiveFailure(let error):
            var state = state
            state.status = .failed(error)
            
            return state
        case .didReceiveResponse(let soundingList):
            var state = state
            state.status = .done(soundingList)
            
            return state
        }
    }
}


