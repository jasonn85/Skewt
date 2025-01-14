//
//  SoundingStateTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 11/15/24.
//

import Testing
import Foundation
@testable import Skewt

struct SoundingStateTests {
    @Test("Current sounding reflects time selection")
    func soundingForTimes() {
        let epoch = Date.now
        
        let intervals: [TimeInterval] = [-.twelveHours, .zero, .twelveHours]
        let soundings = intervals.map {
            SoundingData(
                time: epoch.addingTimeInterval($0),
                elevation: 0,
                dataPoints: [],
                surfaceDataPoint: nil,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )
        }
        
        let soundingList = OpenMeteoSoundingList(
            fetchTime: .now,
            latitude: 0.0,
            longitude: 0.0,
            data: soundings.reduce(into: [Date: SoundingData]()) { $0[$1.time] = $1 }
        )
        
        intervals.forEach { interval in
            let time = epoch.addingTimeInterval(interval)
            
            let relativeSelection = SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .relative(interval),
                dataAgeBeforeRefresh: 24.0 * 60.0 * 60.0
            )
            
            let specificSelection = SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .specific(time),
                dataAgeBeforeRefresh: 24.0 * 60.0 * 60.0
            )
            
            let relativeState = SoundingState(selection: relativeSelection, status: .done(soundingList))
            let specificState = SoundingState(selection: specificSelection, status: .done(soundingList))
            
            #expect(relativeState.sounding!.data.time == time)
            #expect(specificState.sounding!.data.time == time)
        }
    }
    
    @Test("Changing time selection works",
          arguments: [
            SoundingSelection.Time.now,
            .numberOfSoundingsAgo(-10),
            .numberOfSoundingsAgo(0),
            .numberOfSoundingsAgo(1),
            .relative(-.twentyFourHours),
            .relative(.zero),
            .relative(.twelveHours),
            .specific(Date(timeIntervalSince1970: 1735936978.0))
          ]
    )
    func changeTime(timeSelection: SoundingSelection.Time) {
        let originalState = SoundingState(
            selection: SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: 24.0 * 60.0 * 60.0
            ),
            status: .idle
        )
        
        let state = SoundingState.reducer(
            originalState,
            SoundingState.Action.changeAndLoadSelection(.selectTime(timeSelection))
        )
        
        #expect(state.selection.time == timeSelection)
    }
    
    @Test("Change/load selection from idle state causes loading state",
          arguments: [
            SoundingSelection.Action.selectTime(.now),
            SoundingSelection.Action.selectTime(.relative(60.0 * 60.0)),
            SoundingSelection.Action.selectTime(.relative(-60.0 * 60.0)),
            SoundingSelection.Action.selectTime(.relative(24.0 * 60.0 * 60.0)),
            SoundingSelection.Action.selectTime(.specific(Date(timeIntervalSince1970: 1731695293))),
            SoundingSelection.Action.selectModelType(.automaticForecast, .now),
            SoundingSelection.Action.selectLocation(.closest, .now),
            SoundingSelection.Action.selectLocation(.point(latitude: 39.8563, longitude: -104.6764), .now),
            SoundingSelection.Action.selectModelTypeAndLocation(.automaticForecast, .closest, .now)
          ]
    )
    func changeAndLoadFromIdle(selectionAction: SoundingSelection.Action) {
        let state = SoundingState(
            selection: SoundingSelection(type: .automaticForecast, location: .closest, time: .now, dataAgeBeforeRefresh: .fifteenMinutes),
            status: .idle
        )
                
        switch SoundingState.reducer(state, SoundingState.Action.changeAndLoadSelection(selectionAction)).status {
        case .loading:
            return
        default:
            Issue.record("Change/load selection did not effect a loading state")
        }
    }
    
    @Test("Change/load selection with recent data does not change state",
          arguments: [
            SoundingSelection.Action.selectTime(.now),
            SoundingSelection.Action.selectModelType(.automaticForecast, .now),
            SoundingSelection.Action.selectLocation(.closest, .now),
            SoundingSelection.Action.selectModelTypeAndLocation(.automaticForecast, .closest, .now)
          ])
    func changeLoadWithAlreadyGoodData(selectionAction: SoundingSelection.Action) {
        let soundingData = SoundingData(
            time: .now,
            elevation: 0,
            dataPoints: [],
            surfaceDataPoint: nil,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )
        
        let state = SoundingState(
            selection: SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: .fifteenMinutes
            ),
            status: .done(OpenMeteoSoundingList(
                fetchTime: .now,
                latitude: 39.8563,
                longitude: -104.6764,
                data: [.now: soundingData]
            )))
        
        switch SoundingState.reducer(state, SoundingState.Action.changeAndLoadSelection(selectionAction)).status {
        case .done(_):
            return
        default:
            Issue.record("Changing/loading with already existing data improperly effected another load")
        }
    }
    
    @Test("Change time to a time we have in existing, recent data does not change state")
    func changeTimeWithDataPresent() {
        let soundingData = SoundingData(
            time: .now,
            elevation: 0,
            dataPoints: [],
            surfaceDataPoint: nil,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )
        
        let state = SoundingState(
            selection: SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: .fifteenMinutes
            ),
            status: .done(OpenMeteoSoundingList(
                fetchTime: .now,
                latitude: 39.8563,
                longitude: -104.6764,
                data: [
                    .now: soundingData,
                    .now.addingTimeInterval(.oneHour): soundingData
                ]
            )))
        
        let timeSelection = SoundingSelection.Action.selectTime(.relative(.oneHour))
        
        switch SoundingState.reducer(state, SoundingState.Action.changeAndLoadSelection(timeSelection)).status {
        case .done(_):
            return
        default:
            Issue.record("Changing/loading with already existing data improperly effected another load")
        }
    }
    
    @Test("Change time to a time we have in existing, recent data results in change of time selection")
    func changeTimeWorksWithExistingData() {
        let soundingData = SoundingData(
            time: .now,
            elevation: 0,
            dataPoints: [],
            surfaceDataPoint: nil,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )
        
        let startingState = SoundingState(
            selection: SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: .fifteenMinutes
            ),
            status: .done(OpenMeteoSoundingList(
                fetchTime: .now,
                latitude: 39.8563,
                longitude: -104.6764,
                data: [
                    .now: soundingData,
                    .now.addingTimeInterval(.oneHour): soundingData
                ]
            )))
        
        let timeSelection = SoundingSelection.Action.selectTime(.relative(.oneHour))
        let endState = SoundingState.reducer(startingState, SoundingState.Action.changeAndLoadSelection(timeSelection))
        
        switch endState.selection.time {
        case .relative(.oneHour):
            return
        case .relative(let interval):
            Issue.record("Relative time selection was \(interval) instead of one hour. That's odd.")
        default:
            Issue.record("Changing time selection with existing data erased the selection of a new time.")
        }
    }
    
    @Test("Changing time to now with hour old data effects a load")
    func reloadWithOldData() {
        let soundingData = SoundingData(
            time: .now.addingTimeInterval(-.oneHour),
            elevation: 0,
            dataPoints: [],
            surfaceDataPoint: nil,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )
        
        let state = SoundingState(
            selection: SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: .fifteenMinutes
            ),
            status: .done(OpenMeteoSoundingList(
                fetchTime: .now.addingTimeInterval(-.oneHour),
                latitude: 39.8563,
                longitude: -104.6764,
                data: [.now: soundingData,]
            )))
        
        switch SoundingState.reducer(state, SoundingState.Action.changeAndLoadSelection(.selectTime(.now))).status {
        case .loading, .refreshing(_):
            return
        default:
            Issue.record("Changing time with stale data did not effect a load")
        }
    }
    
    @Test("Appropriate data for time selection",
          arguments: 0..<12)
    func timeSelection(timeIndex: Int) {
        let dates = stride(from: TimeInterval.zero, to: TimeInterval.twelveHours, by: .oneHour).map {
            Date.now.addingTimeInterval($0)
        }
        
        var data: [Date: SoundingData] = [:]
        
        dates.forEach {
            data[$0] = SoundingData(
                time: $0,
                elevation: 0,
                dataPoints: [],
                surfaceDataPoint: nil,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )
        }
        
        let specificTimeState = SoundingState(
            selection: SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .specific(dates[timeIndex]),
                dataAgeBeforeRefresh: .fifteenMinutes
            ),
            status: .done(OpenMeteoSoundingList(
                fetchTime: .now,
                latitude: 39.8563,
                longitude: -104.6764,
                data: data
            )))
        
        #expect(specificTimeState.sounding?.data.time == dates[timeIndex], "Specific time selection results in correct data")
        
        let relativeTimeState = SoundingState.reducer(
            specificTimeState,
            SoundingState.Action.changeAndLoadSelection(
                .selectTime(.relative(.oneHour * Double(timeIndex))))
        )
        
        #expect(relativeTimeState.sounding?.data.time == dates[timeIndex], "Relative time selection results in correct data")
    }
    
    @Test("Changing time selection to a time outside of our current data causes a load")
    func needMoreData() {
        let dates = stride(from: TimeInterval.zero, to: TimeInterval.twelveHours, by: .oneHour).map {
            Date.now.addingTimeInterval($0)
        }
        
        var data: [Date: SoundingData] = [:]
        
        dates.forEach {
            data[$0] = SoundingData(
                time: $0,
                elevation: 0,
                dataPoints: [],
                surfaceDataPoint: nil,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )
        }
        
        let state = SoundingState(
            selection: SoundingSelection(
                type: .automaticForecast,
                location: .closest,
                time: .now,
                dataAgeBeforeRefresh: .fifteenMinutes
            ),
            status: .done(OpenMeteoSoundingList(
                fetchTime: .now,
                latitude: 39.8563,
                longitude: -104.6764,
                data: data
            )))
        
        let tomorrowState = SoundingState.reducer(
            state,
            SoundingState.Action.changeAndLoadSelection(.selectTime(.relative(.oneDay)))
        )
        
        switch tomorrowState.status {
        case .loading:
            return
        default:
            Issue.record("Changing time selection to a time outside of our data didn't trigger a load")
        }
    }
}

extension TimeInterval {
    static let fifteenMinutes = TimeInterval(15.0 * 60.0)
    static let oneHour = TimeInterval(60.0 * 60.0)
    static let twelveHours = oneHour * 12.0
    static let oneDay = twelveHours * 2.0
}
