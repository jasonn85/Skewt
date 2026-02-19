//
//  SkewtStateTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 6/21/23.
//

import XCTest
@testable import Skewt

final class SkewtStateTests: XCTestCase {
    let closestLatestForecast = SoundingSelection(type: .forecast(.automatic), location: .closest, time: .now, dataAgeBeforeRefresh: 15.0 * 60.0)
    let closestLatestRaob = SoundingSelection(type: .sounding, location: .closest, time: .now, dataAgeBeforeRefresh: SoundingSelection.defaultDataAgeBeforeRefresh(for: .sounding))
    let closestSixHourForecast = SoundingSelection(type: .forecast(.automatic), location: .closest, time: .relative(.hours(6)), dataAgeBeforeRefresh: 15.0 * 60.0)

    func testCurrentSoundingSavedInRecents() {
        let originalState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestForecast),
            pinnedSelections: [],
            recentSelections: [closestLatestForecast],
            plotOptions: PlotOptions(),
            locationState: LocationState(),
            recentSoundings: RecentSoundingsState()
        )
        
        let state = SkewtState.reducer(
            originalState,
            SoundingState.Action.selection(.selectModelType(.sounding))
        )
        
        XCTAssertTrue(state.recentSelections.contains { $0 == closestLatestRaob })
    }
    
    func testChangingTimeDoesNotSaveNewRecent() {
        let originalState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestForecast),
            pinnedSelections: [],
            recentSelections: [closestLatestForecast],
            plotOptions: PlotOptions(),
            locationState: LocationState(),
            recentSoundings: RecentSoundingsState()
        )
                
        let state = SkewtState.reducer(
            originalState,
            SoundingState.Action.selection(.selectTime(.relative(.hours(6))))
        )
        
        XCTAssertEqual(state.recentSelections, originalState.recentSelections)
    }
    
    func testRecentsIsCulled() {
        let failsafe = 1000
        var state = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestForecast),
            pinnedSelections: [],
            recentSelections: [closestLatestForecast],
            plotOptions: PlotOptions(),
            locationState: LocationState(),
            recentSoundings: RecentSoundingsState()
        )
        
        for i in 0...failsafe {
            let name = "Location \(i)"
            let recentCount = state.recentSelections.count
            
            state = SkewtState.reducer(state, SoundingState.Action.selection(
                .selectLocation(.named(name: name, latitude: 0.0, longitude: 0.0))
            ))
            
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
        let selection = closestLatestForecast
        
        let originalState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: closestLatestForecast),
            pinnedSelections: [],
            recentSelections: [closestLatestForecast],
            plotOptions: PlotOptions(),
            locationState: LocationState(),
            recentSoundings: RecentSoundingsState()
        )
        
        XCTAssertEqual(originalState.pinnedSelections.count, 0)
        
        let pinnedState = SkewtState.reducer(originalState, SkewtState.Action.pinSelection(selection))
        XCTAssertEqual(pinnedState.pinnedSelections, [selection])
        
        let unpinnedState = SkewtState.reducer(pinnedState, SkewtState.Action.unpinSelection(selection))
        XCTAssertEqual(unpinnedState.pinnedSelections.count, 0)
    }
    
    func testDuplicatePinning() {
        let selection = closestLatestForecast
        
        let pinnedState = SkewtState(
            displayState: DisplayState(),
            currentSoundingState: SoundingState(selection: selection),
            pinnedSelections: [selection],
            recentSelections: [selection],
            plotOptions: PlotOptions(),
            locationState: LocationState(),
            recentSoundings: RecentSoundingsState()
        )
        
        let repinnedState = SkewtState.reducer(pinnedState, SkewtState.Action.pinSelection(selection))
        XCTAssertEqual(pinnedState.pinnedSelections, repinnedState.pinnedSelections)
    }
}
