//
//  ForecastSelectionView.swift
//  Skewt
//
//  Created by Jason Neel on 7/2/23.
//

import SwiftUI
import MapKit

struct ForecastSelectionView: View {
    @EnvironmentObject var store: Store<SkewtState>
    @State var searchText = ""
    var searchCount = 5
    
    var body: some View {
        NavigationView {
            List {
                SoundingSelectionRow(
                    selection: SoundingSelection(
                        type: .op40,
                        location: .closest,
                        time: .now
                    ),
                    subtitle: closestLocationDescription
                )
                
                ForEach(locations, id: \.id) {
                    SoundingSelectionRow(
                        selection: SoundingSelection(
                            type: .op40,
                            location: .named($0.name),
                            time: .now
                        ),
                        title: $0.description,
                        subtitle: $0.name
                    )
                }
            }
            .listStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Search airports")
    }
    
    private var isSearching: Bool {
        searchText.count > 0
    }
    
    private var closestLocationDescription: String? {
        guard let location = store.state.locationState.locationIfKnown,
              let closest = LocationList
            .allLocationTypes
            .locationsSortedByProximity(to: location)
            .first
        else {
            return nil
        }
        
        return "Near \(closest.description)"
    }
    
    private var locations: [LocationList.Location] {
        var locations: [LocationList.Location] = []
        
        if isSearching {
            locations = LocationList
                .allLocationTypes
                .locationsForSearch(searchText)
        } else if let location = store.state.locationState.locationIfKnown {
            locations = LocationList
                .allLocationTypes
                .locationsSortedByProximity(to: location)
        }
        
        return Array(locations.prefix(searchCount))
    }
}

struct ForecastSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore

        ForecastSelectionView()
            .environmentObject(store)
    }
}
