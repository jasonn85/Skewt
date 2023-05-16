//
//  State.swift
//  Skewt
//
//  Created by Jason Neel on 2/23/23.
//

import Foundation
import Combine

protocol Action {}
typealias Reducer<State> = (State, Action) -> State
typealias Middleware<State> = (State, Action) -> AnyPublisher<Action, Never>

fileprivate let dispatchQueueLabel = "com.jasonneel.skewt.store"

extension AnyCancellable {
    func store(in dictionary: inout [UUID: AnyCancellable], key: UUID) {
        dictionary[key] = self
    }
}

final class Store<State>: ObservableObject {
    @Published private(set) var state: State
    
    private var subscriptions: [UUID: AnyCancellable] = [:]
    
    private let queue = DispatchQueue(label: dispatchQueueLabel, qos: .userInitiated)
    private let reducer: Reducer<State>
    private let middlewares: [Middleware<State>]
    
    init(initial state: State, reducer: @escaping Reducer<State>, middlewares: [Middleware<State>]) {
        self.state = state
        self.reducer = reducer
        self.middlewares = middlewares
    }
    
    func dispatch(_ action: Action) {
        queue.sync {
            self.dispatch(action, currentState: self.state)
        }
    }
    
    private func dispatch(_ action: Action, currentState: State) {
        let newState = reducer(currentState, action)
        
        middlewares.forEach {
            let key = UUID()
            
            $0(newState, action)
                .receive(on: DispatchQueue.main)
                .handleEvents(receiveCompletion: { [weak self] _ in
                    self?.subscriptions.removeValue(forKey: key)
                })
                .sink(receiveValue: dispatch)
                .store(in: &subscriptions, key: key)
        }
        
        state = newState
    }
}

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
