//
//  RecentSoundingsState.swift
//  Skewt
//
//  Created by Jason Neel on 6/14/23.
//

import Foundation

struct RecentSoundingsState: Codable {
    enum Action: Skewt.Action, Codable {
        case load
        case refresh
        case loadingListFailed(RecentSoundingsError)
        case didReceiveList(LatestSoundingList)
    }
    
    enum Status: Codable {
        case idle
        case loading
        case refreshing(LatestSoundingList, Date)
        case failed(RecentSoundingsError)
        case done(LatestSoundingList, Date)
    }
    
    enum RecentSoundingsError: Error, Codable {
        case unparseableResponse
        case requestFailed
    }
    
    let status: Status
}

extension RecentSoundingsState {
    init() {
        status = .idle
    }
}

extension RecentSoundingsState {
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? RecentSoundingsState.Action else {
            return state
        }
        
        switch action {
        case .refresh:
            if case RecentSoundingsState.Status.done(let oldList, let oldDate) = state.status {
                return RecentSoundingsState(status: .refreshing(oldList, oldDate))
            }
            
            // If refresh is called with no other data, fall through as a normal .load action
            fallthrough
        case .load:
            return RecentSoundingsState(status: .loading)
        case .loadingListFailed(let error):
            return RecentSoundingsState(status: .failed(error))
        case .didReceiveList(let list):
            return RecentSoundingsState(status: .done(list, Date()))
        }
    }
}
