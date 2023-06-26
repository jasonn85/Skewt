//
//  SkewtStateTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 6/21/23.
//

import XCTest
@testable import Skewt

final class SkewtStateTests: XCTestCase {
    let closestLatestOp40 = SoundingSelection(type: .op40, location: .closest, time: .now)
    let closestLatestRaob = SoundingSelection(type: .raob, location: .closest, time: .now)
    let closestSixHourOp40 = SoundingSelection(type: .op40, location: .closest, time: .relative(.hours(6)))

    func testCurrentSoundingSavedInRecents() {
        let originalState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestOp40),
            pinnedSelections: [],
            recentSelections: [closestLatestOp40],
            plotOptions: PlotOptions(),
            locationState: LocationState()
        )
        
        let state = SkewtState.reducer(
            originalState,
            SoundingState.Action.changeAndLoadSelection(.selectModelType(.raob))
        )
        
        XCTAssertTrue(state.recentSelections.contains { $0 == closestLatestRaob })
    }
    
    func testChangingTimeDoesNotSaveNewRecent() {
        let originalState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestOp40),
            pinnedSelections: [],
            recentSelections: [closestLatestOp40],
            plotOptions: PlotOptions(),
            locationState: LocationState()
        )
                
        let state = SkewtState.reducer(
            originalState,
            SoundingState.Action.changeAndLoadSelection(.selectTime(.relative(.hours(6))))
        )
        
        XCTAssertEqual(state.recentSelections, originalState.recentSelections)
    }
    
    func testRecentsIsCulled() {
        let failsafe = 1000
        var state = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestOp40),
            pinnedSelections: [],
            recentSelections: [closestLatestOp40],
            plotOptions: PlotOptions(),
            locationState: LocationState()
        )
        
        for i in 0...failsafe {
            let name = "Location \(i)"
            let recentCount = state.recentSelections.count
            
            state = SkewtState.reducer(state, SoundingState.Action.changeAndLoadSelection(.selectLocation(.named(name))))
            
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
        
        let originalState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestOp40),
            pinnedSelections: [],
            recentSelections: [closestLatestOp40],
            plotOptions: PlotOptions(),
            locationState: LocationState()
        )
        
        XCTAssertEqual(originalState.pinnedSelections.count, 0)
        
        let pinnedState = SkewtState.reducer(originalState, SkewtState.Action.pinSelection(selection))
        XCTAssertEqual(pinnedState.pinnedSelections, [selection])
        
        let unpinnedState = SkewtState.reducer(pinnedState, SkewtState.Action.unpinSelection(selection))
        XCTAssertEqual(unpinnedState.pinnedSelections.count, 0)
    }
    
    func testDuplicatePinning() {
        let selection = closestLatestOp40
        
        let pinnedState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: selection),
            pinnedSelections: [selection],
            recentSelections: [selection],
            plotOptions: PlotOptions(),
            locationState: LocationState()
        )
        
        let repinnedState = SkewtState.reducer(pinnedState, SkewtState.Action.pinSelection(selection))
        XCTAssertEqual(pinnedState.pinnedSelections, repinnedState.pinnedSelections)
    }
}
