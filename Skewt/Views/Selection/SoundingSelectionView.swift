//
//  SoundingSelectionView.swift
//  Skewt
//
//  Created by Jason Neel on 6/15/23.
//

import SwiftUI
import MapKit

struct SoundingSelectionView: View {
    @EnvironmentObject var store: Store<SkewtState>
    
    var locationListLength = 5
    var soundingDataMaxAge: TimeInterval = 5.0 * 60.0  // five minutes
    
    var body: some View {
        List {
            Section("Nearby Soundings") {
                switch store.state.recentSoundingsState.status {
                case .failed(_), .idle:
                    Text("Failed to load soundings")
                case .loading:
                    HStack {
                        ProgressView()
                        Spacer().frame(width: 10)
                        Text("Loading")
                    }
                default:
                    ForEach(closestLocations, id: \.name) {
                        SoundingSelectionRow(
                            selection: SoundingSelection(
                                type: .raob,
                                location: .named($0.name),
                                time: .now
                            ),
                            titleComponents: [.text($0.name), .text($0.description)],
                            subtitleComponents: subtitleComponents(forStationNamed: $0.name)
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .onAppear {
            let soundingsDataAge = store.state.recentSoundingsState.dataAge
            
            if soundingsDataAge == nil || soundingsDataAge! > soundingDataMaxAge {
                store.dispatch(RecentSoundingsState.Action.refresh)
            }
        }
    }
    
    private var centerLocation: CLLocation {
        store.state.locationState.locationIfKnown ?? CLLocation(latitude: 39.83, longitude: -104.66)
    }
    
    private var closestLocations: [LocationList.Location] {
        var wmoIds: [Int]? = nil
        
        guard let recentSoundings = store.state.recentSoundingsState.recentSoundings?.recentSoundings() else {
            return []
        }
        
        wmoIds = recentSoundings.compactMap {
            switch $0.stationId {
            case .wmoId(let wmoId) :
                return wmoId
            case .bufr(_):
                return nil
            }
        }
        
        guard let locations = try? LocationList.forType(.op40) else {
            return []
        }

        return Array(locations.locationsSortedByProximity(to: centerLocation, onlyWmoIds: wmoIds)[..<locationListLength])
    }
    
    private func subtitleComponents(forStationNamed stationName: String) -> [SoundingSelectionRow.DescriptionComponent]? {
        guard let locations = try? LocationList.forType(.raob).locations,
              let currentLocation = store.state.locationState.locationIfKnown,
              let station = locations.first(where: { $0.name == stationName }) else {
            return nil
        }
        
        let stationLocation = station.clLocation
        let distance = currentLocation.distance(from: stationLocation)
        let direction = currentLocation.bearing(toLocation: stationLocation)
        
        var timeComponents = [SoundingSelectionRow.DescriptionComponent]()
        
        if let wmoId = station.wmoId,
           let ageComponent = lastSoundingComponent(forWmoId: wmoId) {
            timeComponents = [ageComponent]
        }
        
        return timeComponents + [.bearingAndDistance(bearing: direction, distance: distance)]
    }
    
    private func lastSoundingComponent(forWmoId wmoId: Int) -> SoundingSelectionRow.DescriptionComponent? {
        guard let recentSoundings = store.state.recentSoundingsState.recentSoundings?.soundings,
              let entry = recentSoundings.first(where:{ $0.wmoIdOrNil == wmoId }) else {
            return nil
        }
        
        return .age(entry.timestamp)
    }
}

extension SoundingSelection.Location {
    var briefDescription: String {
        switch self {
        case .closest:
            return "Current location"
        case .named(let name):
            return name
        case .point(latitude: let latitude, longitude: let longitude):
            return String(format: "%.0f, %.0f", latitude, longitude)
        }
    }
}

extension SoundingSelection.ModelType {
    var briefDescription: String {
        switch self {
        case .op40:
            return "Op40 forecast"
        case .raob:
            return "Sounding"
        }
    }
}

struct SoundingSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore
        SoundingSelectionView()
            .environmentObject(store)
    }
}
