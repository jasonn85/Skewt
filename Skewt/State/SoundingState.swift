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
        case automatic  // Allow data provider to select the best forecast model
        case op40
        case raob
        
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
        case numberOfSoundingsAgo(Int)  // .numberOfSoundingsAgo(1) is equivalent to .now
        case specific(Date)
        
        var id: Self { self }
    }
    
    let type: ModelType
    let location: Location
    let time: Time
    let dataAgeBeforeRefresh: TimeInterval
    
    var id: Self { self }
}

// Default initializer
extension SoundingSelection {
    init() {
        type = .op40
        location = .closest
        time = .now
        
        let fiveMinutes = TimeInterval(5.0 * 60.0)
        dataAgeBeforeRefresh = fiveMinutes
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
        case .automatic, .op40:
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

extension SoundingSelection.ModelType {
    var hourInterval: Int {
        switch self {
        case .automatic:
            return 1
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
            return SoundingSelection(type: type, location: state.location, time: time, dataAgeBeforeRefresh: state.dataAgeBeforeRefresh)
        case .selectLocation(let location, let time):
            return SoundingSelection(type: state.type, location: location, time: time, dataAgeBeforeRefresh: state.dataAgeBeforeRefresh)
        case .selectTime(let time):
            return SoundingSelection(type: state.type, location: state.location, time: time, dataAgeBeforeRefresh: state.dataAgeBeforeRefresh)
        case .selectModelTypeAndLocation(let type, let location, let time):
            return SoundingSelection(
                type: type ?? state.type,
                location: location ?? state.location,
                time: time,
                dataAgeBeforeRefresh: state.dataAgeBeforeRefresh
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
        case didReceiveResponse(OpenMeteoSoundingList)
    }
    
    enum Status: Codable {
        case idle
        case loading
        case done(OpenMeteoSoundingList)
        case refreshing(OpenMeteoSoundingList)
        case failed(SoundingError)
    }
    
    var selection: SoundingSelection
    var status: Status
    
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
