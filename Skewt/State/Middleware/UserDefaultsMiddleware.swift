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
        switch action as? SoundingState.Action {
        case .changeAndLoadSelection(_):
            UserDefaults.standard.save(state.currentSoundingState.selection, forKey: .currentSelection)
            
        default:
            break
        }
        
        if action as? PlotOptions.Action != nil {
            UserDefaults.standard.save(state.plotOptions, forKey: .plotOptions)
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
