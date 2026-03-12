//
//  SkewtApp.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//

import SwiftUI

@main
struct SkewtApp: App {
    @StateObject private var store = Store(
        initial: SkewtState(),
        reducer: SkewtState.reducer,
        middlewares: [
            Middlewares.locationMiddleware,
            Middlewares.consoleLogger,
            Middlewares.userDefaultsSaving,
            Middlewares.openMeteoApi,
            Middlewares.ncafSoundingMiddleware,
            Middlewares.ncafSoundingData,
            Middlewares.uwySoundingData
        ]
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.appEnvironment, AppEnvironment(isLive: true))
        }
    }
}
