//
//  DisplayState.swift
//  Skewt
//
//  Created by Jason Neel on 6/20/23.
//

import Foundation

struct DisplayState: Codable {
    enum TabSelection: Hashable, Codable {
        case displayOptions
        case recentSelections
        case forecastSelection
        case soundingSelection
    }
    
    enum Action: Skewt.Action {
        case selectTab(TabSelection)
    }
    
    var tabSelection: TabSelection
}

extension DisplayState {
    init() {
        tabSelection = .soundingSelection
    }
}

extension DisplayState {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? DisplayState.Action else {
            return state
        }
        
        switch action {
        case .selectTab(let tabSelection):
            return DisplayState(tabSelection: tabSelection)
        }
    }
}
