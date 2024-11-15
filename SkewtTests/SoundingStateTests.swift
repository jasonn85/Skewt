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
    @Test("Change/load selection from idle state causes loading state",
          arguments: [
            SoundingSelection.Action.selectTime(.now),
            SoundingSelection.Action.selectTime(.relative(60.0 * 60.0)),
            SoundingSelection.Action.selectTime(.relative(-60.0 * 60.0)),
            SoundingSelection.Action.selectTime(.relative(24.0 * 60.0 * 60.0)),
            SoundingSelection.Action.selectTime(.specific(Date(timeIntervalSince1970: 1731695293))),
            SoundingSelection.Action.selectModelType(.automatic, .now),
            SoundingSelection.Action.selectLocation(.closest, .now),
            SoundingSelection.Action.selectLocation(.point(latitude: 39.8563, longitude: -104.6764), .now),
            SoundingSelection.Action.selectModelTypeAndLocation(.automatic, .closest, .now)
          ]
    )
    func changeAndLoadFromIdle(selectionAction: SoundingSelection.Action) {
        let state = SoundingState(
            selection: SoundingSelection(type: .automatic, location: .closest, time: .now, dataAgeBeforeRefresh: .fifteenMinutes),
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
            SoundingSelection.Action.selectModelType(.automatic, .now),
            SoundingSelection.Action.selectLocation(.closest, .now),
            SoundingSelection.Action.selectModelTypeAndLocation(.automatic, .closest, .now)
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
                type: .automatic,
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
                type: .automatic,
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
                type: .automatic,
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
                type: .automatic,
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
                type: .automatic,
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
    static let twelveHours = .oneHour * 12.0
    static let oneDay = twelveHours * 2.0
}
