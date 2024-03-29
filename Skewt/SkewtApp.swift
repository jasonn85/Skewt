//
//  SkewtApp.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//

import SwiftUI

@main
struct SkewtApp: App {
    var body: some Scene {
        let store = Store(
            initial: SkewtState(),
            reducer: SkewtState.reducer,
            middlewares: [
                Middlewares.rucApi,
                Middlewares.soundingsListApi,
                Middlewares.locationMiddleware,
                Middlewares.consoleLogger,
                Middlewares.userDefaultsSaving,
                Middlewares.locationSearchMiddleware,
                Middlewares.updateRaobTimeMiddleware
            ]
        )
        
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
