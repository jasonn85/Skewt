//
//  ConsoleLogMiddleware.swift
//  Skewt
//
//  Created by Jason Neel on 5/27/23.
//

import Foundation
import Combine

extension Middlewares {
    static let consoleLogger: Middleware<SkewtState> = { _, _, action in
        print("\(String(reflecting: type(of: action))): \(action)")
        return Empty().eraseToAnyPublisher()
    }
}
