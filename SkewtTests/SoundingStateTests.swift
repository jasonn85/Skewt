//
//  SoundingStateTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 6/21/23.
//

import XCTest
@testable import Skewt

final class SoundingStateTests: XCTestCase {
    let closestLatestOp40 = SoundingSelection(type: .op40, location: .closest, time: .now)
    let closestLatestRaob = SoundingSelection(type: .raob, location: .closest, time: .now)
    let closestSixHourOp40 = SoundingSelection(type: .op40, location: .closest, time: .relative(.hours(6)))

    func testCurrentSoundingSavedInRecents() {
        let originalState = SoundingState(
            selection: closestLatestOp40,
            pinnedSelections: [],
            recentSelections: [closestLatestOp40],
            status: .idle
        )
        
        let state = SoundingState.reducer(
            originalState,
            SoundingState.Action.changeAndLoadSelection(.selectModelType(.raob))
        )
        
        XCTAssertTrue(state.recentSelections.contains { $0 == closestLatestRaob })
    }
    
    func testChangingTimeDoesNotSaveNewRecent() {
        let originalState = SoundingState(
            selection: closestLatestOp40,
            pinnedSelections: [],
            recentSelections: [closestLatestOp40],
            status: .idle
        )
                
        let state = SoundingState.reducer(
            originalState,
            SoundingState.Action.changeAndLoadSelection(.selectTime(.relative(.hours(6))))
        )
        
        XCTAssertEqual(state.recentSelections, originalState.recentSelections)
    }
    
    func testRecentsIsCulled() {
        let failsafe = 1000
        var state = SoundingState()
        
        for i in 0...failsafe {
            let name = "Location \(i)"
            let recentCount = state.recentSelections.count
            
            state = SoundingState.reducer(state, SoundingState.Action.changeAndLoadSelection(.selectLocation(.named(name))))
            
            if state.recentSelections.count == recentCount {
                // Test complete
                return
            } else if state.recentSelections.count != recentCount + 1 {
                XCTFail("Changing sounding selection should only increment recents count by 1 (or stay the same)")
            }
        }
        
        XCTFail("Recent soundings should cull to a maximum length")
    }
    
    func testPinningAndUnpinning() {
        let selection = closestLatestOp40
        
        let originalState = SoundingState(
            selection: selection,
            pinnedSelections: [],
            recentSelections: [selection],
            status: .idle
        )
        
        XCTAssertEqual(originalState.pinnedSelections.count, 0)
        
        let pinnedState = SoundingState.reducer(originalState, SoundingState.Action.pinSelection(selection))
        XCTAssertEqual(pinnedState.pinnedSelections, [selection])
        
        let unpinnedState = SoundingState.reducer(pinnedState, SoundingState.Action.unpinSelection(selection))
        XCTAssertEqual(unpinnedState.pinnedSelections.count, 0)
    }
    
    func testDuplicatePinning() {
        let selection = closestLatestOp40
        
        let pinnedState = SoundingState(
            selection: selection,
            pinnedSelections: [selection],
            recentSelections: [selection],
            status: .idle
        )
        
        let repinnedState = SoundingState.reducer(pinnedState, SoundingState.Action.pinSelection(selection))
        XCTAssertEqual(pinnedState.pinnedSelections, repinnedState.pinnedSelections)
    }
}
