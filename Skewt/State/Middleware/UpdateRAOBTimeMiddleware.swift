//
//  UpdateRAOBTimeMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 12/12/23.
//

import Foundation
import Combine

extension Middlewares {
    /// This middleware detects if our current selection is most recent sounding and we just received a list of
    /// available soundings that shows the latest data is older than one sounding ago (so the request will return blank data)
    static let updateRaobTimeMiddleware: Middleware<SkewtState> = { state, action in
        guard case .didReceiveList(let soundingList) = action as? RecentSoundingsState.Action,
              case .raob = state.currentSoundingState.selection.type,
              case .named(let locationName) = state.currentSoundingState.selection.location,
              let wmoId = LocationList.allLocations.locationNamed(locationName)?.wmoId,
              let mostRecentSounding = soundingList.lastSoundingTime(forWmoId: wmoId),
              case .numberOfSoundingsAgo(let soundingsAgo) = mostRecentSounding.soundingSelectionTime(forModelType: .raob),
              soundingsAgo > 1
        else {
            return Empty().eraseToAnyPublisher()
        }
        
        return Just(SoundingState.Action.changeAndLoadSelection(.selectTime(.numberOfSoundingsAgo(soundingsAgo))))
            .eraseToAnyPublisher()
    }
}
