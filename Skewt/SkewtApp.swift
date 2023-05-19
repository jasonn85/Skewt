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
            initial: State(),
            reducer: State.reducer,
            middlewares: [Middlewares.locationMiddleware]
        )
        
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}
