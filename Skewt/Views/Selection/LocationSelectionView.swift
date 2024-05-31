//
//  LocationSelectionView.swift
//  Skewt
//
//  Created by Jason Neel on 5/17/24.
//

import SwiftUI
import CoreLocation

struct LocationSelectionView: View {    
    @EnvironmentObject var store: Store<SkewtState>
    var listType: ListType = .all
    
    enum ListType {
        case all
        case modelType(SoundingSelection.ModelType)
        case favoritesAndRecents
    }
    
    private var searchCount = 20
    private var locationListLength = 5
    private var soundingDataMaxAge: TimeInterval = 5.0 * 60.0  // five minutes
    
    @State private var selectedModelType: SoundingSelection.ModelType = .op40
    @State private var searchText: String = ""
    @FocusState private var isSearching: Bool
    
    init(listType: ListType = .all) {
        self.listType = listType
    }
    
    var body: some View {
        List {
            if showFavoritesAndRecents {
                if !store.state.pinnedSelections.isEmpty {
                    Section("Favorites") {
                        ForEach(store.state.pinnedSelections, id: \.id) {
                            SoundingSelectionRow(
                                selection: $0,
                                titleComponents: pinnedTitleComponents(forSelection: $0),
                                subtitleComponents: [.type]
                            )
                            .environmentObject(store)
                        }
                    }
                }
                
                if !store.state.recentSelections.isEmpty {
                    Section("Recents") {
                        ForEach(store.state.recentSelections, id: \.id) {
                            SoundingSelectionRow(
                                selection: $0,
                                titleComponents: pinnedTitleComponents(forSelection: $0),
                                subtitleComponents: [.type]
                            )
                            .environmentObject(store)
                        }
                    }
                }
            }
            
            if showList {
                // We want `Section {}` for a nonexistent section header in some cases. Section(nil) or Section("") do not achieve that.
                if let listTitle = listTitle {
                    Section(listTitle) {
                        listContents
                    }
                } else {
                    Section {
                        listContents
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText)
        .onChange(of: searchText) {
            store.dispatch(ForecastSelectionState.Action.setSearchText(searchText))
        }
        .onAppear {
            let soundingsDataAge = store.state.recentSoundingsState.dataAge
            
            if soundingsDataAge == nil || soundingsDataAge! > soundingDataMaxAge {
                store.dispatch(RecentSoundingsState.Action.refresh)
            }
            
            store.dispatch(ForecastSelectionState.Action.load)
        }
    }
    
    private var showFavoritesAndRecents: Bool {
        guard searchText.isEmpty else {
            return false
        }
        
        switch listType {
        case .all, .favoritesAndRecents:
            return true
        case .modelType(_):
            return false
        }
    }
    
    private var showList: Bool {
        switch listType {
        case .favoritesAndRecents:
            return false
        case .all, .modelType(_):
            return true
        }
    }
    
    private var listTitle: String? {
        switch listType {
        case .all:
            return "Locations"
        case .modelType(_), .favoritesAndRecents:
            return nil
        }
    }
    
    @ViewBuilder
    private var listContents: some View {
        switch listType {
        case .all:
            Picker("Type", selection: $selectedModelType) {
                Text("Forecast")
                    .tag(SoundingSelection.ModelType.op40)
                
                Text("Sounding")
                    .tag(SoundingSelection.ModelType.raob)
            }
            .pickerStyle(.segmented)
            
            switch selectedModelType {
            case .op40:
                op40List
            case .raob:
                raobList
            }
        case .modelType(let modelType):
            switch modelType {
            case .op40:
                op40List
            case .raob:
                raobList
            }
        case .favoritesAndRecents:
            EmptyView()
        }
    }
    
    private var showNearestForecastRow: Bool {
        switch store.state.displayState.forecastSelectionState.searchType {
        case .nearest:
            return true
        case .text(_):
            return false
        }
    }
    
    @ViewBuilder
    private var nearestForecastRow: some View {
        if showNearestForecastRow {
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
    
    private var loadingView: some View {
        HStack {
            ProgressView()
            Spacer().frame(width: 10)
            Text("Loading")
        }
    }
    
    @ViewBuilder
    private var noResultsRow: some View {
        HStack {
            Spacer().frame(width: 42)
            Text("No results")
        }
    }
    
    @ViewBuilder
    private var op40List: some View {
        switch store.state.displayState.forecastSelectionState.searchStatus {
        case .loading:
            if showNearestForecastRow {
                nearestForecastRow
            }
            
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                Spacer()
            }
            .id(UUID())
        case .done(let locations):
            nearestForecastRow
            
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
    private var raobList: some View {
        switch store.state.recentSoundingsState.status {
        case .loading:
            loadingView
        case .done(_, _), .refreshing(_, _):
            let locations = raobLocations
            
            ForEach(locations, id: \.name) {
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
            
            if locations.isEmpty {
                Text("No results")
            }
        case .failed(_), .idle:
            Text("Failed to load soundings")
        }
    }
    
    private var raobLocations: [LocationList.Location] {
        switch store.state.displayState.forecastSelectionState.searchType {
        case .nearest:
            return closestSoundingLocations
        case .text(let searchText):
            guard let allSoundings = try? LocationList.forType(.raob) else {
                return []
            }
            
            return allSoundings.locationsForSearch(searchText)
        }
    }
    
    private var centerLocation: CLLocation {
        store.state.locationState.locationIfKnown ?? CLLocation(latitude: 39.83, longitude: -104.66)
    }
    
    private var closestSoundingLocations: [LocationList.Location] {
        var wmoIds: [Int]? = nil
        
        guard let recentSoundings = store.state.recentSoundingsState.recentSoundings?.recentSoundings(),
              recentSoundings.count > 0 else {
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
    
    private func pinnedTitleComponents(
        forSelection selection: SoundingSelection
    ) -> [SoundingSelectionRow.DescriptionComponent] {
        guard case .named(let stationName) = selection.location,
              let location = LocationList.allLocations.locationNamed(stationName) else {
            return [.selectionDescription]
        }
        
        return [.text(location.name), .text(location.description)]
    }
    
    private func subtitleComponents(forStationNamed stationName: String) -> [SoundingSelectionRow.DescriptionComponent]? {
        guard let locationList = try? LocationList.forType(.raob),
              let currentLocation = store.state.locationState.locationIfKnown,
              let station = locationList.locationNamed(stationName) else {
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
        guard let recentSoundings = store.state.recentSoundingsState.recentSoundings,
              let soundingTime = recentSoundings.lastSoundingTime(forWmoId: wmoId) else {
            return nil
        }
        
        return .age(soundingTime)
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

#Preview {
    let store = Store<SkewtState>.previewStore
    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
    
    if isPhone {
        return VStack {
            Rectangle()
                .frame(minHeight: 350.0)
            
            LocationSelectionView()
                .environmentObject(store)
        }
    } else {
        return NavigationSplitView(columnVisibility: Binding<NavigationSplitViewVisibility>(get:{.doubleColumn}, set: {_ in })) {
            LocationSelectionView()
                .environmentObject(store)
        } detail: {
            Rectangle()
        }
    }
}
