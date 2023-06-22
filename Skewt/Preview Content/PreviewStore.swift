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
    
    static var previewStore: Store<SkewtState> {
        let selection = SoundingSelection()
        
        let soundingState = SoundingState(
            selection: selection,
            status: .done(previewSounding)
        )
        
        return Store<SkewtState>(
            initial: SkewtState(
                currentSoundingState: soundingState,
                defaultSoundingSelection: soundingState.selection,
                pinnedSelections: [],
                recentSelections: [selection],
                plotOptions: PlotOptions(),
                locationState: LocationState()
            ),
            reducer: SkewtState.reducer,
            middlewares: []
        )
    }
}
