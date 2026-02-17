//
//  NCAFSoundingMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 2/17/26.
//

import Foundation
import Combine
import OSLog

extension Middlewares {
    static let ncafSoundingMiddleware: Middleware<SkewtState> = { oldState, state, action in
        switch state.recentSoundings.status {
        case .loading, .refreshing(_):
            return URLSession.shared.dataTaskPublisher(for: NCAFSoundingList.url)
                .map { data, response in
                    guard !data.isEmpty,
                          let text = String(data: data, encoding: .utf8),
                          let list = NCAFSoundingList(fromString: text) else {
                        return RecentSoundingsState.Action.didReceiveFailure(.unparseableResponse)
                    }
                    
                    return RecentSoundingsState.Action.didReceiveData(list)
                }
                .replaceError(with: RecentSoundingsState.Action.didReceiveFailure(.requestFailed))
                .eraseToAnyPublisher()
            
        case .idle, .done(_), .failed(_):
            return Empty().eraseToAnyPublisher()
        }
    }
}
