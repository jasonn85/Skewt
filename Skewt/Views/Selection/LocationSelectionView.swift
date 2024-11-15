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
    private var soundingDataMaxAge: TimeInterval = 5.0 * 60.0  // five minutes
    
    @State private var selectedModelType: SoundingSelection.ModelType = .op40
    @State private var searchText: String = ""
    
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
                // We want `Section {}` for a nonexistent section header in some cases. Section(nil) or Section("") does not achieve that.
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
        .searchable(isSearchable: showSearch, text: $searchText)
        .autocorrectionDisabled()
        .onChange(of: searchText) {
            store.dispatch(ForecastSelectionState.Action.setSearchText(searchText))
        }
        .onAppear {
            store.dispatch(ForecastSelectionState.Action.load)
        }
    }
    
    private var showSearch: Bool {
        switch listType {
        case .all, .modelType(_):
            true
        case .favoritesAndRecents:
            false
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
            case .op40, .automatic:
                op40List
            case .raob:
                raobList
            }
        case .modelType(let modelType):
            switch modelType {
            case .op40, .automatic:
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
                    time: .now,
                    dataAgeBeforeRefresh: 15.0 * 60.0
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
                            time: .now,
                            dataAgeBeforeRefresh: 15.0 * 60.0
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
        Text("Failed to load soundings")
        
        // TODO: Remove
//        switch store.state.recentSoundingsState.status {
//        case .loading:
//            loadingView
//        case .done(_, _), .refreshing(_, _):
//            let locations = raobLocations
//            
//            ForEach(locations.prefix(searchCount), id: \.name) {
//                SoundingSelectionRow(
//                    selection: SoundingSelection(
//                        type: .raob,
//                        location: .named($0.name),
//                        time: .now
//                    ),
//                    titleComponents: [.text($0.name), .text($0.description)],
//                    subtitleComponents: subtitleComponents(forStationNamed: $0.name)
//                )
//            }
//            
//            if locations.isEmpty {
//                noResultsRow
//            }
//        case .failed(_), .idle:
//            Text("Failed to load soundings")
//        }
    }
    
    private var raobLocations: [LocationList.Location] {
        // TODO: Remove
        return []
        
//        guard let recentSoundings = store.state.recentSoundingsState.recentSoundings?.recentSoundings(),
//              recentSoundings.count > 0 else {
//            return []
//        }
//        
//        let wmoIds = recentSoundings.compactMap {
//            switch $0.stationId {
//            case .wmoId(let wmoId) :
//                return wmoId
//            case .bufr(_):
//                return nil
//            }
//        }
//                
//        switch store.state.displayState.forecastSelectionState.searchType {
//        case .nearest:
//            guard let locations = try? LocationList.forType(.op40) else {
//                return []
//            }
//            
//            return Array(locations.locationsSortedByProximity(to: centerLocation, onlyWmoIds: wmoIds)[..<searchCount])
//        case .text(let searchText):
//            guard let allSoundings = try? LocationList.forType(.raob) else {
//                return []
//            }
//            
//            return allSoundings.locationsForSearch(searchText).filter {
//                guard let wmoId = $0.wmoId else {
//                    return false
//                }
//                
//                return wmoIds.contains(wmoId)
//            }
//        }
    }
    
    private var centerLocation: CLLocation {
        store.state.locationState.locationIfKnown ?? CLLocation(latitude: 39.83, longitude: -104.66)
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
        // TODO: Remove
        return nil
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

struct OptionallySearchable: ViewModifier {
    let isSearchable: Bool
    @Binding var searchText: String
    
    func body(content: Content) -> some View {
        switch isSearchable {
        case true:
            content.searchable(text: $searchText)
        case false:
            content
        }
    }
}

extension View {
    func searchable(isSearchable searchable: Bool, text: Binding<String>) -> some View {
        modifier(OptionallySearchable(isSearchable: searchable, searchText: text))
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
