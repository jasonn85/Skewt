//
//  RecentSoundingsState.swift
//  Skewt
//
//  Created by Jason Neel on 2/17/26.
//

import Foundation

struct RecentSoundingsState: Codable {
    let status: Status
    
    static let ageToDiscardOldDataOnRefresh: TimeInterval = 24.0 * 60.0 * 60.0  // 24 hours
    
    var soundingList: NCAFSoundingList? {
        switch status {
        case .done(let sounding), .refreshing(let sounding):
            return sounding
        case .idle, .loading, .failed(_):
            return nil
        }
    }
    
    enum Action: Skewt.Action {
        case load
        case didReceiveData(NCAFSoundingList)
        case didReceiveFailure(SoundingListError)
    }
    
    enum SoundingListError: Error {
        case requestFailed
        case unparseableResponse
    }
    
    enum Status: Codable {
        case idle
        case loading
        case failed(SoundingListError)
        case refreshing(NCAFSoundingList)
        case done(NCAFSoundingList)
        
        // Since our entire purpose is ephemeral sounding data, we will not encode/decode to anything
        //  other than .idle
        init(from decoder: any Decoder) throws {
            self = .idle
        }
        
        func encode(to encoder: any Encoder) throws {
            return
        }
    }
    
    static let reducer: Reducer<Self> = { state, action in
        guard let action = action as? RecentSoundingsState.Action else {
            return state
        }
        
        switch action {
        case .load:
            if let oldData = state.soundingList,
               Date.now.timeIntervalSince(oldData.timestamp) < RecentSoundingsState.ageToDiscardOldDataOnRefresh {
                return RecentSoundingsState(status: .refreshing(oldData))
            } else {
                return RecentSoundingsState(status: .loading)
            }
            
        case .didReceiveData(let soundingList):
            return RecentSoundingsState(status: .done(soundingList))
            
        case .didReceiveFailure(let error):
            return RecentSoundingsState(status: .failed(error))
        }
    }
}

extension RecentSoundingsState {
    init() {
        self = RecentSoundingsState(status: .idle)
    }
}

extension RecentSoundingsState.Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .didReceiveData(let list):
            return "Received recent soundings for \(list.messagesByStationId.count) stations"
        case .didReceiveFailure(let error):
            switch error {
            case .requestFailed:
                return "Request failed"
            case .unparseableResponse:
                return "Response was unparseable"
            }
        case .load:
            return "Loading"
        }
    }
}
