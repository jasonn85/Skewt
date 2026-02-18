//
//  PreviewStore.swift
//  Skewt
//
//  Created by Jason Neel on 5/22/23.
//

import SwiftUI

extension Store {
    static var previewSoundingList: OpenMeteoSoundingList {
        let previewData = NSDataAsset(name: "open-meteo-sample")!.data
        return try! OpenMeteoSoundingList(fromData: previewData)
    }
    
    private static var previewPinnedSelections: [SoundingSelection] {
        [
            SoundingSelection(
                type: .forecast(.automatic),
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: 15.0 * 60.0
            ),
            SoundingSelection(
                type: .sounding,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: 15.0 * 60.0
            ),
            SoundingSelection(
                type: .forecast(.automatic),
                location: .named(name: "SAN", latitude: 32.73, longitude: -117.18),
                time: .now,
                dataAgeBeforeRefresh: 15.0 * 60.0
            ),
        ]
    }
    
    static var previewStore: Store<SkewtState> {
        let selection = SoundingSelection()
        
        var soundingState = SoundingState(selection: selection)
        soundingState.openMeteoList = previewSoundingList
        soundingState.openMeteoSelection = selection
        if let closest = previewSoundingList.closestSounding() {
            soundingState.resolvedSounding = ResolvedSounding(openMeteoSounding: closest)
        }
        
        return Store<SkewtState>(
            initial: SkewtState(
                displayState: DisplayState(),
                currentSoundingState: soundingState,
                pinnedSelections: previewPinnedSelections,
                recentSelections: [selection],
                plotOptions: PlotOptions(),
                locationState: LocationState(),
                recentSoundings: RecentSoundingsState()
            ),
            reducer: SkewtState.reducer,
            middlewares: []
        )
    }
}
