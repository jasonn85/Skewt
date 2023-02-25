//
//  State.swift
//  Skewt
//
//  Created by Jason Neel on 2/23/23.
//

import Foundation

protocol Action {}
typealias Reducer<State> = (State, Action) -> State

struct State {
    let soundingScreenState: SoundingScreenState
    
    init() {
        soundingScreenState = SoundingScreenState()
    }
}

struct SoundingScreenState {
    let soundingState: SoundingState
    let annotationState: AnnotationState
}

extension SoundingScreenState {
    init() {
        soundingState = .blank
        annotationState = AnnotationState()
    }
}

enum SoundingState {
    case blank
    case loading(SoundingRequest)
    case ready(Sounding)
}

struct AnnotationState {
    
}
