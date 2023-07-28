//
//  RecentSoundingsState.swift
//  Skewt
//
//  Created by Jason Neel on 6/14/23.
//

import Foundation

struct RecentSoundingsState: Codable {
    enum Action: Skewt.Action, Codable {
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

extension RecentSoundingsState.Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .refresh:
            return "Refreshing recent soundings list"
        case .loadingListFailed(let error):
            return "Loading recent soundings failed: \(error)"
        case .didReceiveList(let list):
            return "Received list of \(list.soundings.count) recent soundings"
        }
    }
}

extension RecentSoundingsState {
    var recentSoundings: LatestSoundingList? {
        switch status {
        case.done(let list, _), .refreshing(let list, _):
            return list
        case .failed(_), .idle, .loading:
            return nil
        }
    }
    
    var dataAge: TimeInterval? {
        switch status {
        case .done(_, let date), .refreshing(_, let date):
            return Date.now.timeIntervalSince(date)
        case .failed(_), .idle, .loading:
            return nil
        }
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
            
            return RecentSoundingsState(status: .loading)
        case .loadingListFailed(let error):
            return RecentSoundingsState(status: .failed(error))
        case .didReceiveList(let list):
            return RecentSoundingsState(status: .done(list, .now))
        }
    }
}
