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
        let soundingState = SoundingState(selection: SoundingSelection(), status: .done(previewSounding))
        
        return Store<SkewtState>(
            initial: SkewtState(
                currentSoundingState: soundingState,
                defaultSoundingSelection: soundingState.selection,
                plotOptions: PlotOptions(),
                locationState: LocationState()
            ),
            reducer: SkewtState.reducer,
            middlewares: []
        )
    }
}
