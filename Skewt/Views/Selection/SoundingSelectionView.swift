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
    
    var distanceFormatter: MKDistanceFormatter {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        
        return formatter
    }
    
    var body: some View {
        List {
            Section("Nearby Soundings") {
                ForEach(closestLocations, id: \.name) {
                    SoundingSelectionRow(
                        selection: SoundingSelection(
                            type: store.state.currentSoundingState.selection.type,
                            location: .named($0.name),
                            time: .now
                        ),
                        title: "\($0.name) - \($0.description)",
                        subtitle: relativeLocationDescription(forStationName: $0.name)
                    )
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
        
        guard let recentSoundings = store.state.recentSoundingsState.recentSoundings else {
            return []
        }
        
        wmoIds = recentSoundings.soundings.compactMap {
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
    
    private func relativeLocationDescription(forStationName name: String) -> String? {
        guard let locations = try? LocationList.forType(.raob).locations,
              let currentLocation = store.state.locationState.locationIfKnown,
              let station = locations.first(where: { $0.name == name }) else {
            return nil
        }

        let stationLocation = station.clLocation
        let distance = currentLocation.distance(from: stationLocation)
        let direction = currentLocation.ordinalDirection(toLocation: stationLocation)

        return "\(distanceFormatter.string(fromDistance: distance)) \(direction.shortDescription)"
    }
}

extension OrdinalDirection {
    var shortDescription: String {
        switch self {
        case .north:
            return "N"
        case .northeast:
            return "NE"
        case .east:
            return "E"
        case .southeast:
            return "SE"
        case .south:
            return "S"
        case .southwest:
            return "SW"
        case .west:
            return "W"
        case .northwest:
            return "NW"
        }
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
