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
        let intervals: [TimeInterval] = [-TimeInterval.hours(12), .zero, TimeInterval.hours(12)]

        let soundings = intervals.map {
            SoundingData(
                time: epoch.addingTimeInterval($0),
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

            let selection = SoundingSelection(
                type: .forecast(.automatic),
                location: .closest,
                time: .relative(interval),
                dataAgeBeforeRefresh: 24.0 * 60.0 * 60.0
            )

            var state = SoundingState(selection: selection)
            state.openMeteoList = soundingList
            state.openMeteoSelection = selection

            let resolved = SoundingState.reducer(state, SoundingState.Action.selection(.selectTime(.relative(interval))))
            #expect(resolved.resolvedSounding?.data.time == time)
            #expect(resolved.loadIntent == nil)
        }
    }

    @Test("Missing or stale list yields load intent")
    func loadIntentWhenStale() {
        let selection = SoundingSelection(
            type: .forecast(.automatic),
            location: .closest,
            time: .now,
            dataAgeBeforeRefresh: 15.0 * 60.0
        )

        var state = SoundingState(selection: selection)
        state.openMeteoList = OpenMeteoSoundingList(
            fetchTime: .now.addingTimeInterval(-TimeInterval.hours(12)),
            latitude: 0.0,
            longitude: 0.0,
            data: [Date.now: SoundingData(
                time: .now,
                dataPoints: [],
                surfaceDataPoint: nil,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )]
        )
        state.openMeteoSelection = selection

        let resolved = SoundingState.reducer(state, SoundingState.Action.selection(.selectTime(.now)))
        #expect(resolved.loadIntent == .openMeteo(selection))
        #expect(resolved.resolvedSounding == nil)
    }

    @Test("Forecast uses cached Open-Meteo when available")
    func forecastUsesCachedOpenMeteo() {
        let selection = SoundingSelection(
            type: .forecast(.automatic),
            location: .closest,
            time: .now,
            dataAgeBeforeRefresh: TimeInterval.hours(12)
        )

        let data = SoundingData(
            time: selection.timeAsConcreteDate,
            dataPoints: [],
            surfaceDataPoint: nil,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )

        var state = SoundingState(selection: selection)
        state.openMeteoList = OpenMeteoSoundingList(
            fetchTime: .now,
            latitude: 0.0,
            longitude: 0.0,
            data: [data.time: data]
        )
        state.openMeteoSelection = selection

        let resolved = SoundingState.reducer(state, SoundingState.Action.selection(.selectTime(.now)))

        #expect(resolved.resolvedSounding?.data.time == data.time)
        #expect(resolved.loadIntent == nil)
    }

    @Test("Refresh forces a load intent")
    func refreshForcesLoad() {
        let selection = SoundingSelection(
            type: .forecast(.automatic),
            location: .closest,
            time: .now,
            dataAgeBeforeRefresh: TimeInterval.hours(12)
        )

        var state = SoundingState(selection: selection)
        state.openMeteoList = OpenMeteoSoundingList(
            fetchTime: .now,
            latitude: 0.0,
            longitude: 0.0,
            data: [Date.now: SoundingData(
                time: .now,
                dataPoints: [],
                surfaceDataPoint: nil,
                cape: nil,
                cin: nil,
                helicity: nil,
                precipitableWater: nil
            )]
        )
        state.openMeteoSelection = selection

        let resolved = SoundingState.reducer(state, SoundingState.Action.refreshTapped)
        #expect(resolved.loadIntent == .openMeteo(selection))
        #expect(resolved.resolvedSounding == nil)
    }

    @Test("Historical sounding uses UWY intent")
    func historicalSoundingUsesUwy() {
        let selection = SoundingSelection(
            type: .sounding,
            location: .closest,
            time: .relative(-TimeInterval.hours(12)),
            dataAgeBeforeRefresh: TimeInterval.hours(12)
        )

        let state = SoundingState(selection: selection)
        let resolved = SoundingState.reducer(state, SoundingState.Action.selection(.selectTime(selection.time)))

        #expect(resolved.loadIntent == .uwy(selection))
        #expect(resolved.resolvedSounding == nil)
    }

    @Test("Historical sounding uses cached UWY when available")
    func historicalSoundingUsesCachedUwy() {
        let selection = SoundingSelection(
            type: .sounding,
            location: .closest,
            time: .relative(-TimeInterval.hours(12)),
            dataAgeBeforeRefresh: TimeInterval.hours(12)
        )

        let data = SoundingData(
            time: selection.timeAsConcreteDate,
            dataPoints: [],
            surfaceDataPoint: nil,
            cape: nil,
            cin: nil,
            helicity: nil,
            precipitableWater: nil
        )

        var state = SoundingState(selection: selection)
        state.uwySounding = UWYSounding(data: data)
        state.uwySelection = selection

        let resolved = SoundingState.reducer(state, SoundingState.Action.selection(.selectTime(selection.time)))

        #expect(resolved.resolvedSounding?.data.time == data.time)
        #expect(resolved.loadIntent == nil)
    }

    @Test("Latest sounding uses NCAF intent")
    func latestSoundingUsesNcaf() {
        let selection = SoundingSelection(
            type: .sounding,
            location: .closest,
            time: .now,
            dataAgeBeforeRefresh: TimeInterval.hours(12)
        )

        let state = SoundingState(selection: selection)
        let resolved = SoundingState.reducer(state, SoundingState.Action.selection(.selectTime(.now)))

        #expect(resolved.loadIntent == .ncaf(selection))
        #expect(resolved.resolvedSounding == nil)
    }

    @Test("Latest sounding uses cached NCAF when available")
    func latestSoundingUsesCachedNcaf() {
        guard let list = loadNcafList(),
              let location = locationMatching(list: list),
              let stationId = location.wmoId,
              let data = list.soundingData(forStationId: stationId) else {
            Issue.record("Failed to load NCAF test data or find matching station")
            return
        }

        let selection = SoundingSelection(
            type: .sounding,
            location: .named(name: location.name, latitude: location.latitude, longitude: location.longitude),
            time: .now,
            dataAgeBeforeRefresh: TimeInterval.hours(12)
        )

        var state = SoundingState(selection: selection)
        state.ncafList = list

        let resolved = SoundingState.reducer(state, SoundingState.Action.selection(.selectTime(.now)))

        #expect(resolved.resolvedSounding?.data.time == data.time)
        #expect(resolved.loadIntent == nil)
    }
}

private final class NcafTestBundleToken {}

private extension SoundingStateTests {
    func loadNcafList() -> NCAFSoundingList? {
        let bundle = Bundle(for: NcafTestBundleToken.self)
        guard let url = bundle.url(forResource: "Current", withExtension: "rawins"),
              let text = try? String(contentsOf: url) else {
            return nil
        }

        return NCAFSoundingList(fromString: text)
    }

    func locationMatching(list: NCAFSoundingList) -> LocationList.Location? {
        LocationList.allLocations.locations.first { location in
            guard let wmoId = location.wmoId else {
                return false
            }

            return list.messagesByStationId[wmoId] != nil
        }
    }
}
