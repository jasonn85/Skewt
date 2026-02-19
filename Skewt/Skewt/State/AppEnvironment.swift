//
//  AppEnvironment.swift
//  Skewt
//
//  Created by Jason Neel on 2/19/26.
//

import SwiftUI

struct AppEnvironment {
    let isLive: Bool
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment(isLive: true)
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
