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
    var searchCount = 20
    
    private var state: ForecastSelectionState {
        store.state.displayState.forecastSelectionState
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                List {
                    locationsList
                    loadingView
                }
                .listStyle(.plain)
            }
        }
        .searchable(
            text: Binding<String>(get: {
                guard case .text(let text) = state.searchType else {
                    return ""
                }
                
                return text
            }, set: {
                store.dispatch(ForecastSelectionState.Action.setSearchText($0))
            }),
            prompt: "Search airports")
        .onAppear {
            store.dispatch(ForecastSelectionState.Action.load)
        }
    }
    
    @ViewBuilder
    private var locationsList: some View {
        switch state.searchStatus {
        case .loading:
            if showNearestRow {
                nearestRow
            } else {
                EmptyView()
            }
        case .done(let locations):
            nearestRow
            
            if locations.count == 0 {
                noResultsRow
            } else {
                ForEach(locations.prefix(searchCount), id: \.id) {
                    SoundingSelectionRow(
                        selection: SoundingSelection(
                            type: .op40,
                            location: .named($0.name),
                            time: .now
                        ),
                        titleComponents: [.text($0.description)],
                        subtitleComponents: [.text($0.name)]
                    )
                }
            }
        case .idle:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        switch state.searchStatus {
        case.loading:
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                Spacer()
            }
            .id(UUID())
        case .done(_), .idle:
            EmptyView()
        }
    }
    
    private var showNearestRow: Bool {
        switch state.searchType {
        case .nearest:
            return true
        case .text(_):
            return false
        }
    }
    
    @ViewBuilder
    private var nearestRow: some View {
        if showNearestRow {
            SoundingSelectionRow(
                selection: SoundingSelection(
                    type: .op40,
                    location: .closest,
                    time: .now
                ),
                subtitleComponents: nearestSubtitleComponents
            )
        } else {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var noResultsRow: some View {
        HStack {
            Spacer().frame(width: 42)
            Text("No results")
        }
    }
    
    private var nearestSubtitleComponents: [SoundingSelectionRow.DescriptionComponent]? {
        guard let closestLocationDescription = closestLocationDescription else {
            return nil
        }
        
        return [.text(closestLocationDescription)]
    }
    
    private var closestLocationDescription: String? {
        guard let location = store.state.locationState.locationIfKnown,
              let closest = LocationList
            .allLocations
            .locationsSortedByProximity(to: location)
            .first
        else {
            return nil
        }
        
        return "Near \(closest.description)"
    }
}

struct ForecastSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore

        ForecastSelectionView()
            .environmentObject(store)
    }
}
