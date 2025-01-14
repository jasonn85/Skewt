//
//  PreviewStore.swift
//  Skewt
//
//  Created by Jason Neel on 5/22/23.
//

import SwiftUI

extension Store {
    static var previewSounding: RucSounding {
        let previewData = NSDataAsset(name: "op40-sample")!.data
        let previewDataString = String(decoding: previewData, as: UTF8.self)
        return try! RucSounding(fromText: previewDataString)
    }
    
    private static var previewPinnedSelections: [SoundingSelection] {
        [
            SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: 15.0 * 60.0
            ),
            SoundingSelection(
                type: .raob,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: 15.0 * 60.0
            ),
            SoundingSelection(
                type: .automaticForecast,
                location: .named(name: "SAN", latitude: 32.73, longitude: -117.18),
                time: .now,
                dataAgeBeforeRefresh: 15.0 * 60.0
            ),
        ]
    }
    
    static var previewStore: Store<SkewtState> {
        let selection = SoundingSelection()
        
        // TODO: Place Open-Meteo placeholder data
        let soundingState = SoundingState(
            selection: selection,
            status: .idle
        )
        
        return Store<SkewtState>(
            initial: SkewtState(
                displayState: DisplayState(),
                currentSoundingState: soundingState,
                pinnedSelections: previewPinnedSelections,
                recentSelections: [selection],
                plotOptions: PlotOptions(),
                locationState: LocationState()
            ),
            reducer: SkewtState.reducer,
            middlewares: []
        )
    }
}
