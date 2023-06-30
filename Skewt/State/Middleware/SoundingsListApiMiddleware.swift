//
//  SoundingsListApiMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 6/14/23.
//

import Foundation
import Combine

extension Middlewares {
    static let soundingsListApi: Middleware<SkewtState> = { state, action in
        guard case RecentSoundingsState.Action.refresh = action else {
            return Empty().eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: LatestSoundingList.url)
            .map { data, response in
                guard !data.isEmpty,
                      let text = String(data: data, encoding: .utf8),
                      let list = try? LatestSoundingList(text) else {
                    return RecentSoundingsState.Action.loadingListFailed(.unparseableResponse)
                }
                
                return RecentSoundingsState.Action.didReceiveList(list)
            }
            .replaceError(with: RecentSoundingsState.Action.loadingListFailed(.requestFailed))
            .eraseToAnyPublisher()
    }
}

