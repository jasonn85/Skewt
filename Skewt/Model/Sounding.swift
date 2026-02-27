//
//  Sounding.swift
//  Skewt
//
//  Created by Jason Neel on 10/28/24.
//

import Foundation

protocol Sounding: Codable, Sendable {
    var data: SoundingData { get }
}
