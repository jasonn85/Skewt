//
//  State.swift
//  Skewt
//
//  Created by Jason Neel on 2/23/23.
//

import Foundation
import Combine
import SwiftUI

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

struct SkewtState: Codable {
    enum Action: Skewt.Action {
        case saveSelectionAsDefault
        case pinSelection(SoundingSelection)
        case unpinSelection(SoundingSelection)
    }
    
    var displayState: DisplayState
    var currentSoundingState: SoundingState
    var defaultSoundingSelection: SoundingSelection
    var pinnedSelections: [SoundingSelection]
    var recentSelections: [SoundingSelection]
    
    var plotOptions: PlotOptions
    var locationState: LocationState
}

// Default initializer
extension SkewtState {
    init() {
        displayState = DisplayState.saved ?? DisplayState()
        defaultSoundingSelection = SoundingSelection.savedCurrentSelection ?? SoundingSelection()
        currentSoundingState = SoundingState(selection: defaultSoundingSelection)
        recentSelections = [defaultSoundingSelection]
        pinnedSelections = []
        plotOptions = PlotOptions.saved ?? PlotOptions()
        locationState = LocationState()
    }
}

// Reducer
extension SkewtState {
    static let reducer: Reducer<Self> = { state, action in
        var state = state
        
        state.displayState = DisplayState.reducer(state.displayState, action)
        state.currentSoundingState = SoundingState.reducer(state.currentSoundingState, action)
        state.defaultSoundingSelection = state.defaultSoundingSelection
        state.plotOptions = PlotOptions.reducer(state.plotOptions, action)
        state.locationState = LocationState.reducer(state.locationState, action)
        
        switch action as? SkewtState.Action {
        case .saveSelectionAsDefault:
            state.defaultSoundingSelection = state.currentSoundingState.selection
        case .pinSelection(let selection):
            print("state before pinning: \(state)")
            state.pinnedSelections = state.pinnedSelections.addingToHead(selection)
            print("state after pinning: \(state)")
        case .unpinSelection(let selection):
            state.pinnedSelections = state.pinnedSelections.filter { $0 != selection }
        case .none:
            break
        }
        
        if case .changeAndLoadSelection(let selectionAction) = action as? SoundingState.Action,
           selectionAction.isCreatingNewSelection {
            
            let maximumRecentSelections = 5
            state.recentSelections = state.recentSelections.addingToHead(
                state.currentSoundingState.selection,
                maximumCount: maximumRecentSelections
            )
        }
        
        return state
    }
}

extension Array where Element: Equatable {
    public func addingToHead(_ element: Element, maximumCount: Int? = nil) -> Self {
        let maximumCount = maximumCount ?? self.count + 1
        
        return [element] + self.filter({ $0 != element }).prefix(maximumCount - 1)
    }
}
