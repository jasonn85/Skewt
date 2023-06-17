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
                Middlewares.locationMiddleware,
                Middlewares.consoleLogger,
                Middlewares.userDefaultsSaving
            ]
        )
        
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
