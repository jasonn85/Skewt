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
enum Middlewares {}

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

struct State: Codable {
    enum Action: Skewt.Action {
        case saveSelectionAsDefault
    }
    
    let currentSoundingState: SoundingState
    let defaultSoundingSelection: SoundingSelection
    let plotOptions: PlotOptions
    let locationState: LocationState
}

// Default initializer
extension State {
    init() {
        currentSoundingState = SoundingState()
        defaultSoundingSelection = SoundingSelection()
        plotOptions = PlotOptions()
        locationState = LocationState()
    }
}

// Reducer
extension State {
    static let reducer: Reducer<Self> = { state, action in
        if action as? Action == .saveSelectionAsDefault {
            return State(currentSoundingState: state.currentSoundingState,
                         defaultSoundingSelection: state.currentSoundingState.selection,
                         plotOptions: state.plotOptions,
                         locationState: state.locationState)
        }
        
        return State(currentSoundingState: SoundingState.reducer(state.currentSoundingState, action),
                     defaultSoundingSelection: state.defaultSoundingSelection,
                     plotOptions: PlotOptions.reducer(state.plotOptions, action),
                     locationState: LocationState.reducer(state.locationState, action))
    }
}