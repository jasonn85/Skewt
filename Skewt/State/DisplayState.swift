//
//  DisplayState.swift
//  Skewt
//
//  Created by Jason Neel on 6/20/23.
//

import Foundation
import Combine

struct DisplayState: Codable {
    enum DialogSelection: Hashable, Codable {
        case displayOptions
        case locationSelection(LocationDialogSelection)
    }
    
    enum LocationDialogSelection: Codable {
        case recent
        case forecast
        case sounding
    }
    
    enum Action: Skewt.Action {
        case showDialog(DialogSelection)
        case hideDialog
    }
    
    var dialogSelection: DialogSelection?
    var lastLocationDialogSelection: LocationDialogSelection
    
    var forecastSelectionState: ForecastSelectionState
}

struct ForecastSelectionState: Hashable {
    enum SearchType: Hashable, Codable {
        case nearest
        case text(String)
    }
    
    enum SearchStatus: Hashable, Codable {
        case idle
        case loading
        case done([LocationList.Location])
    }
    
    enum Action: Skewt.Action {
        case load
        case setSearchText(String?)
        case didFinishSearch(SearchType, [LocationList.Location])
    }
    
    var searchType: SearchType
    var searchStatus: SearchStatus = .idle
}

extension DisplayState {
    init() {
        dialogSelection = nil
        lastLocationDialogSelection = .forecast
        
        forecastSelectionState = ForecastSelectionState()
    }
}

extension ForecastSelectionState {
    init() {
        searchType = .nearest
        searchStatus = .idle
    }
}

extension ForecastSelectionState: Codable {
    private enum CodingKeys: String, CodingKey {
        case searchType
    }
}

extension ForecastSelectionState.Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .didFinishSearch(let searchType, let locations):
            switch searchType {
            case .nearest:
                return "Loaded \(locations.count) nearby locations"
            case .text(let text):
                return "Loaded \(locations.count) locations near \(text)"
            }
        case .load:
            return "Loading"
        case .setSearchText(let text):
            return "Search text changed: \(text ?? "")"
        }
    }
}

extension DisplayState {
    static let reducer: Reducer<Self> = { state, action in
        if let action = action as? DisplayState.Action {
            switch action {
            case .showDialog(let dialogSelection):
                var lastLocationSelection: LocationDialogSelection
                
                switch dialogSelection {
                case .locationSelection(let locationSelection):
                    lastLocationSelection = locationSelection
                default:
                    lastLocationSelection = state.lastLocationDialogSelection
                }
                
                return DisplayState(
                    dialogSelection: dialogSelection,
                    lastLocationDialogSelection: lastLocationSelection,
                    forecastSelectionState: state.forecastSelectionState
                )
                
            case .hideDialog:
                return DisplayState(
                    dialogSelection: nil,
                    lastLocationDialogSelection: state.lastLocationDialogSelection,
                    forecastSelectionState: state.forecastSelectionState
                )
            }
        }
        
        if let action = action as? ForecastSelectionState.Action {
            return DisplayState(
                dialogSelection: state.dialogSelection,
                lastLocationDialogSelection: state.lastLocationDialogSelection,
                forecastSelectionState: ForecastSelectionState.reducer(state.forecastSelectionState, action)
            )
        }
        
        return state
    }
}

extension ForecastSelectionState {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? Action else {
            return state
        }
        
        var state = state
        
        switch action {
        case .load:
            state.searchStatus = .loading
        case .setSearchText(let text):
            let oldSearchType = state.searchType
            
            if let text = text, text.count > 0 {
                state.searchType = .text(text)
            } else {
                state.searchType = .nearest
            }
            
            if state.searchType != oldSearchType {
                state.searchStatus = .loading
            }
        case .didFinishSearch(let searchType, let result):
            guard searchType == state.searchType else {
                return state
            }
            
            state.searchStatus = .done(result)
        }
        
        return state
    }
}
