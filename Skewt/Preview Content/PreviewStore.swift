//
//  PreviewStore.swift
//  Skewt
//
//  Created by Jason Neel on 5/22/23.
//

import SwiftUI

extension Store {
    static var previewSounding: Sounding {
        let previewData = NSDataAsset(name: "op40-sample")!.data
        let previewDataString = String(decoding: previewData, as: UTF8.self)
        return try! Sounding(fromText: previewDataString)
    }
    
    private static var previewPinnedSelections: [SoundingSelection] {
        [
            SoundingSelection(
                type: .op40,
                location: .closest,
                time: .now
            ),
            SoundingSelection(
                type: .raob,
                location: .closest,
                time: .now
            ),
            SoundingSelection(
                type: .op40,
                location: .named("SAN"),
                time: .now
            ),
        ]
    }
    
    static var previewStore: Store<SkewtState> {
        let selection = SoundingSelection()
        
        let soundingState = SoundingState(
            selection: selection,
            status: .done(previewSounding, .now)
        )
        
        return Store<SkewtState>(
            initial: SkewtState(
                displayState: DisplayState(),
                currentSoundingState: soundingState,
                pinnedSelections: previewPinnedSelections,
                recentSelections: [selection],
                plotOptions: PlotOptions(),
                locationState: LocationState(),
                recentSoundingsState: RecentSoundingsState()
            ),
            reducer: SkewtState.reducer,
            middlewares: []
        )
    }
}
