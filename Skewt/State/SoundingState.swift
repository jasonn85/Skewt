//
//  SoundingState.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/23.
//

import Foundation
import CoreLocation

struct SoundingState: Codable, Equatable {
    var selection: SoundingSelection

    // Latest data from each source
    var openMeteoList: OpenMeteoSoundingList?
    var openMeteoSelection: SoundingSelection?
    var ncafList: NCAFSoundingList?
    var uwySounding: UWYSounding?
    var uwySelection: SoundingSelection?

    // Resolved output for the UI
    var resolvedSounding: ResolvedSounding?

    // Derived request intent for middleware
    var loadIntent: LoadIntent?

    // Last request error, if any
    var lastError: SoundingError?

    enum SoundingError: Error, Codable, Equatable {
        case unableToGenerateRequestFromSelection
        case emptyResponse
        case unparseableResponse
        case requestFailed
        case lackingLocationPermission  // We can't do closest weather if we lack CL permission
    }

    enum LoadIntent: Codable, Equatable {
        case openMeteo(SoundingSelection)
        case ncaf(SoundingSelection)
        case uwy(SoundingSelection)
    }

    enum Action: Skewt.Action {
        case selection(SoundingSelection.Action)
        case refreshTapped
        case openMeteoLoaded(OpenMeteoSoundingList)
        case ncafLoaded(NCAFSoundingList)
        case uwyLoaded(UWYSounding)
        case requestFailed(SoundingError)
    }

    enum CodingKeys: String, CodingKey {
        case selection
    }
}

struct ResolvedSounding: Codable, Equatable, Sounding {
    enum Source: Codable, Equatable {
        case openMeteo(fetchTime: Date)
        case ncaf(timestamp: Date)
        case uwy
    }

    let data: SoundingData
    let source: Source
}

// Default initializer
extension SoundingState {
    init() {
        selection = SoundingSelection()
        openMeteoList = nil
        openMeteoSelection = nil
        ncafList = nil
        uwySounding = nil
        uwySelection = nil
        resolvedSounding = nil
        loadIntent = nil
        lastError = nil
    }

    init(selection: SoundingSelection?) {
        self.selection = selection ?? SoundingSelection()
        openMeteoList = nil
        openMeteoSelection = nil
        ncafList = nil
        uwySounding = nil
        uwySelection = nil
        resolvedSounding = nil
        loadIntent = nil
        lastError = nil
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selection = try container.decode(SoundingSelection.self, forKey: .selection)
        openMeteoList = nil
        openMeteoSelection = nil
        ncafList = nil
        uwySounding = nil
        uwySelection = nil
        resolvedSounding = nil
        loadIntent = nil
        lastError = nil
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(selection, forKey: .selection)
    }

    var isLoading: Bool {
        loadIntent != nil && lastError == nil
    }

    var sounding: Sounding? {
        resolvedSounding
    }

    static func == (lhs: SoundingState, rhs: SoundingState) -> Bool {
        lhs.selection == rhs.selection
            && lhs.openMeteoList == rhs.openMeteoList
            && lhs.openMeteoSelection == rhs.openMeteoSelection
            && lhs.uwySounding == rhs.uwySounding
            && lhs.uwySelection == rhs.uwySelection
            && lhs.resolvedSounding == rhs.resolvedSounding
            && lhs.loadIntent == rhs.loadIntent
            && lhs.lastError == rhs.lastError
    }
}

extension ResolvedSounding {
    init(openMeteoSounding: OpenMeteoSounding) {
        data = openMeteoSounding.data
        source = .openMeteo(fetchTime: openMeteoSounding.fetchTime)
    }

    init(ncafData: SoundingData, timestamp: Date) {
        data = ncafData
        source = .ncaf(timestamp: timestamp)
    }

    init(uwySounding: UWYSounding) {
        data = uwySounding.data
        source = .uwy
    }
}

extension SoundingState.Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .refreshTapped:
            return "Refreshing"
        case .selection(let selection):
            return "Changing selection: \(selection)"
        case .requestFailed(let error):
            return "Failed to load sounding: \(error)"
        case .openMeteoLoaded(let soundingList):
            return "Received list of \(soundingList.data.count) sounding\(soundingList.data.count != 1 ? "s" : "")"
        case .ncafLoaded(let soundingList):
            return "Received recent soundings for \(soundingList.messagesByStationId.count) stations"
        case .uwyLoaded:
            return "Received UWY sounding"
        }
    }
}

// Reducer
extension SoundingState {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? Action else {
            return state
        }

        var state = state

        switch action {
        case .selection(let selectionAction):
            state.selection = SoundingSelection.reducer(state.selection, selectionAction)
            state.lastError = nil
            resolve(state: &state, forceReload: false)

        case .refreshTapped:
            state.lastError = nil
            resolve(state: &state, forceReload: true)

        case .openMeteoLoaded(let soundingList):
            state.openMeteoList = soundingList
            state.openMeteoSelection = state.selection
            resolve(state: &state, forceReload: false)

        case .ncafLoaded(let soundingList):
            state.ncafList = soundingList
            resolve(state: &state, forceReload: false)

        case .uwyLoaded(let sounding):
            state.uwySounding = sounding
            state.uwySelection = state.selection
            resolve(state: &state, forceReload: false)

        case .requestFailed(let error):
            state.lastError = error
            resolve(state: &state, forceReload: false)
        }

        return state
    }
}

private extension SoundingState {
    static func resolve(state: inout SoundingState, forceReload: Bool) {
        let previousError = state.lastError

        state.resolvedSounding = nil
        state.loadIntent = nil

        switch state.selection.type {
        case .forecast:
            resolveForecast(state: &state, forceReload: forceReload)
        case .sounding:
            resolveSounding(state: &state, forceReload: forceReload)
        }

        if state.resolvedSounding != nil {
            state.lastError = nil
        } else {
            state.lastError = previousError
        }
    }

    static func resolveForecast(state: inout SoundingState, forceReload: Bool) {
        let selection = state.selection

        if !forceReload,
           let list = state.openMeteoList,
           let listSelection = state.openMeteoSelection,
           listSelection.isEqualIgnoringTime(to: selection),
           Date.now.timeIntervalSince(list.fetchTime) < selection.dataAgeBeforeRefresh,
           let closest = list.closestSounding(toDate: selection.timeAsConcreteDate) {

            let maxDistance = TimeInterval(selection.type.hourInterval) * 60.0 * 60.0
            if abs(closest.date.timeIntervalSince(selection.timeAsConcreteDate)) <= maxDistance {
                state.resolvedSounding = ResolvedSounding(openMeteoSounding: closest)
                return
            }
        }

        state.loadIntent = .openMeteo(selection)
    }

    static func resolveSounding(state: inout SoundingState, forceReload: Bool) {
        let selection = state.selection
        let shouldUseHistorical = selection.requiresHistoricalSounding

        if shouldUseHistorical {
            if !forceReload,
               let uwy = state.uwySounding,
               let uwySelection = state.uwySelection,
               uwySelection == selection {
                state.resolvedSounding = ResolvedSounding(uwySounding: uwy)
                return
            }

            state.loadIntent = .uwy(selection)
            return
        }

        if !forceReload,
           let list = state.ncafList,
           let stationId = stationId(for: selection),
           let data = list.soundingData(forStationId: stationId) {
            state.resolvedSounding = ResolvedSounding(ncafData: data, timestamp: list.timestamp)
            return
        }

        state.loadIntent = .ncaf(selection)
    }

    static func stationId(for selection: SoundingSelection) -> Int? {
        switch selection.location {
        case .closest:
            return nil
        case .named(let name, _, _):
            if let list = try? LocationList.forType(.sounding) {
                return list.locationNamed(name)?.wmoId
            }

            return LocationList.allLocations.locationNamed(name)?.wmoId
        case .point(let latitude, let longitude):
            let location = CLLocation(latitude: latitude, longitude: longitude)
            guard let list = try? LocationList.forType(.sounding) else {
                return nil
            }

            return list.locationsSortedByProximity(to: location).first { $0.wmoId != nil }?.wmoId
        }
    }
}
private extension SoundingSelection {
    var requiresHistoricalSounding: Bool {
        switch time {
        case .now:
            return false
        case .numberOfSoundingsAgo(let count):
            return count > 0
        case .relative, .specific:
            return true
        }
    }
}
