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

struct State: Codable {
    let currentSoundingState: SoundingState
    let defaultSoundingSelection: SoundingSelection
    let plotOptions: PlotOptions
}

extension State {
    init() {
        currentSoundingState = SoundingState()
        defaultSoundingSelection = SoundingSelection()
        plotOptions = PlotOptions()
    }
}

struct SoundingSelection: Codable {
    enum ModelType: Codable {
        case op40
        case raob
    }
    
    enum Location: Codable {
        case closest
        case point(latitude: Double, longitude: Double)
        case named(String)
    }
    
    enum Time: Codable {
        case now
        case relative(TimeInterval)
        case specific(Date)
    }
    
    let type: ModelType
    let location: Location
    let time: Time
}

extension SoundingSelection {
    init() {
        type = .op40
        location = .closest
        time = .now
    }
}

struct SoundingState: Codable {
    enum SoundingError: Error, Codable {
        // TODO: Implement
        case unknown
    }
    
    enum Status: Codable {
        case idle
        case loading
        case done(Sounding)
        case refreshing(Sounding)
        case failed(SoundingError)
    }
    
    let selection: SoundingSelection
    let status: Status
}

extension SoundingState {
    init() {
        selection = SoundingSelection()
        status = .idle
    }
}

struct PlotOptions: Codable {
    struct PlotStyling: Codable {
        enum PlotType: Codable {
            case temperature
            case dewPoint
            case isotherms
            case zeroIsotherm
            case altitudeIsobars
            case pressureIsobars
            case dryAdiabats
            case moistAdiabats
        }
        
        struct LineStyle: Codable {
            let lineWidth: CGFloat
            let color: String
            let opacity: CGFloat
            let dashed: Bool
        }
        
        let lineStyles: [PlotType: LineStyle]
    }
    
    enum IsothermTypes: Codable {
        case none
        case tens
        case zeroOnly
    }
    
    enum IsobarTypes: Codable {
        case none
        case altitude
        case pressure
    }
    
    enum AdiabatTypes: Codable {
        case none
        case tens
    }
        
    let altitudeRange: Range<Double>?
    let isothermTypes: IsothermTypes
    let isobarTypes: IsobarTypes
    let adiabatTypes: AdiabatTypes
    let showMixingLines: Bool
    let showIsobarLabels: Bool
    let showIsothermLabels: Bool
}

extension PlotOptions {
    init() {
        altitudeRange = nil
        isothermTypes = .tens
        isobarTypes = .altitude
        adiabatTypes = .tens
        showMixingLines = false
        showIsobarLabels = true
        showIsothermLabels = true
    }
}
