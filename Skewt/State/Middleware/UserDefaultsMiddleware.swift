//
//  UserDefaultsMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 6/16/23.
//

import Foundation
import Combine

extension UserDefaults {
    enum SkewtKey: String {
        case currentSelection = "skewt.currentSelection"
        case plotOptions = "skewt.plotOptions"
        case displayState = "skewt.displayState"
        case recentSelections = "skewt.recentSelections"
        case pinnedSelections = "skewt.pinnedSelections"
    }
    
    func save<T: Encodable>(_ value: T, forKey key: SkewtKey) {
        let encoder = JSONEncoder()
        
        if let json = try? encoder.encode(value) {
            set(json, forKey: key.rawValue)
        }
    }
    
    func loadValue<T: Decodable>(forKey key: SkewtKey) -> T? {
        guard let encoded = object(forKey: key.rawValue) as? Data else {
            return nil
        }
        
        let decoder = JSONDecoder()
        
        return try? decoder.decode(T.self, from: encoded)
    }
 }

extension Middlewares {
    static let userDefaultsSaving: Middleware<SkewtState> = { state, action in
        switch action as? SkewtState.Action {
        case .pinSelection(_), .unpinSelection(_):
            UserDefaults.standard.save(state.pinnedSelections, forKey: .pinnedSelections)
        default:
            break
        }
        
        switch action as? SoundingState.Action {
        case .changeAndLoadSelection(_):
            UserDefaults.standard.save(state.currentSoundingState.selection, forKey: .currentSelection)
            UserDefaults.standard.save(state.recentSelections, forKey: .recentSelections)
            
        default:
            break
        }
        
        if action is PlotOptions.Action || action is PlotOptions.PlotStyling.Action {
            UserDefaults.standard.save(state.plotOptions, forKey: .plotOptions)
        }
        
        if action is DisplayState.Action {
            UserDefaults.standard.save(state.displayState, forKey: .displayState)
        }
        
        return Empty().eraseToAnyPublisher()
    }
}

extension SoundingSelection {
    static var savedCurrentSelection: SoundingSelection? {
        UserDefaults.standard.loadValue(forKey: .currentSelection) as Self?
    }
}

extension PlotOptions {
    static var saved: PlotOptions? {
        UserDefaults.standard.loadValue(forKey: .plotOptions) as Self?
    }
}

extension DisplayState {
    static var saved: DisplayState? {
        UserDefaults.standard.loadValue(forKey: .displayState) as Self?
    }
}

extension SkewtState {
    static var savedRecentSelections: [SoundingSelection]? {
        UserDefaults.standard.loadValue(forKey: .recentSelections) as [SoundingSelection]?
    }
    
    static var savedPinnedSelections: [SoundingSelection]? {
        UserDefaults.standard.loadValue(forKey: .pinnedSelections) as [SoundingSelection]?
    }
}
