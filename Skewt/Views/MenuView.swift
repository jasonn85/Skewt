//
//  MenuView.swift
//  Skewt
//
//  Created by Jason Neel on 2/24/26.
//

import SwiftUI
import CoreLocation
import MapKit
#if os(iOS)
import UIKit
#endif

struct MenuView: View {
    private struct SoundingAnnotationItem: Identifiable {
        let stationId: Int
        let location: LocationList.Location
        let soundingData: SoundingData?
        
        var id: String { "\(stationId)-\(location.name)" }
    }
    
    private static let soundingLocationsByWmoId: [Int: [LocationList.Location]] = try! LocationList.forType(.sounding).locations
        .sorted { $0.name < $1.name }
        .reduce(into: [Int: [LocationList.Location]]()) { locationsByWmoId, location in
            guard let wmoId = location.wmoId else {
                return
            }
            
            locationsByWmoId[wmoId, default: []].append(location)
        }

    @EnvironmentObject var store: Store<SkewtState>

    @State private var soundingOrForecast = SoundingOrForecast.forecast
    @State private var forecastModel = SoundingSelection.ForecastModel.automatic
    @State private var location = SoundingSelection.Location.closest
    let onReturnToSelection: (() -> Void)?
    
    private static let mapZoom = 1_000_000.0  // 1,000 km
    @State private var mapPosition: MapCameraPosition = .camera(
        MapCamera(centerCoordinate: .denver, distance: MenuView.mapZoom)
    )
    @State private var selectedAnnotationID: String?
    @State private var soundingAnnotationItems: [SoundingAnnotationItem] = []
    
    @State private var searchText = ""
    
    enum SoundingOrForecast {
        case sounding
        case forecast
    }

    init(onReturnToSelection: (() -> Void)? = nil) {
        self.onReturnToSelection = onReturnToSelection
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Forecast or Sounding", selection: $soundingOrForecast) {
                    Text("Forecast")
                        .tag(SoundingOrForecast.forecast)
                    Text("Sounding")
                        .tag(SoundingOrForecast.sounding)
                }
                .pickerStyle(.segmented)
                .tint(.menuSectionHeaderGradient1)
                .foregroundStyle(.menuTitle)
            }
            .padding()
            
            switch soundingOrForecast {
            case .sounding:
                soundingSelectionView
            case .forecast:
                forecastSelectionView
            }
            
            Spacer(minLength: 0)
        }
        .background(Gradient(colors: [.menuBackgroundGradient1, .menuBackgroundGradient2]))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if let onReturnToSelection = onReturnToSelection {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onReturnToSelection()
                    } label: {
                        Image(systemName: "chevron.forward")
                    }
                    .foregroundStyle(.menuTitle)
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar)
        .searchSuggestions {
            ForEach(searchSuggestionLocations, id: \.self) {
                row(forLocation: $0)
            }
        }
        .onAppear {
            configurePickerTypography()
            requestLocationForNearbyForecastsIfNeeded()
            
            searchText = ""
            forecastModel = store.state.currentSoundingState
                .selection.type.forecastModel ?? .automatic
            location = store.state.currentSoundingState.selection.location
        }
        .onChange(of: store.state.locationState) { oldLocationState, locationState in
            guard store.state.currentSoundingState.selection.requiresLocation,
                  oldLocationState.locationIfKnown == nil,
                  locationState.locationIfKnown != nil else {
                return
            }
            
            mapPosition = initialMapPosition
        }
    }
    
    @ViewBuilder
    private var soundingSelectionView: some View {
        VStack {
            Map(
                position: $mapPosition,
                interactionModes: [.pan, .zoom],
                selection: $selectedAnnotationID
            ) {
                ForEach(soundingAnnotationItems) { item in
                    switch item.soundingData {
                    case .some(let data):
                        Annotation(item.location.description, coordinate: item.location.coordinate, anchor: .bottom) {
                            SoundingMapAnnotation(data: data)
                                .frame(width: 50, height: 50)
                        }
                        .tag(item.id)
                    case .none:
                        Marker(item.location.description, coordinate: item.location.coordinate)
                            .tag(item.id)
                    }
                }
            }
            .frame(maxHeight: 500)
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation {
                        mapPosition = userPosition
                    }
                } label: {
                    Image(systemName: "location")
                        .padding(12)
                }
                .glassEffect(in: Circle())
                .padding()
            }
            .onAppear {
                mapPosition = initialMapPosition
                refreshSoundingAnnotationItems()
            }
            .onChange(of: store.state.recentSoundings.soundingList?.timestamp) { _, _ in
                refreshSoundingAnnotationItems()
            }
            .onChange(of: selectedAnnotationID) { _, selectedAnnotationID in
                guard
                    let selectedAnnotationID,
                    let item = soundingAnnotationItems.first(where: { $0.id == selectedAnnotationID })
                else {
                    return
                }

                selectLatestSounding(forLocation: item.location)
                self.selectedAnnotationID = nil
            }
        }
    }
    
    private func buildSoundingAnnotationItems() -> [SoundingAnnotationItem] {
        let soundingList = store.state.recentSoundings.soundingList

        return Self.soundingLocationsByWmoId.keys
            .sorted()
            .compactMap { stationId in
                guard let locations = Self.soundingLocationsByWmoId[stationId] else {
                    return nil
                }

                let representativeLocation: LocationList.Location?
                if let soundingList {
                    representativeLocation = representativeSoundingLocation(
                        forStationId: stationId,
                        from: locations,
                        using: soundingList
                    )
                } else {
                    representativeLocation = locations.first
                }

                guard let representativeLocation else {
                    return nil
                }
                
                return SoundingAnnotationItem(
                    stationId: stationId,
                    location: representativeLocation,
                    soundingData: soundingList?.soundingData(forStationId: stationId)
                )
            }
    }

    private func refreshSoundingAnnotationItems() {
        soundingAnnotationItems = buildSoundingAnnotationItems()
    }
    
    private func representativeSoundingLocation(
        forStationId stationId: Int,
        from locations: [LocationList.Location],
        using soundingList: NCAFSoundingList
    ) -> LocationList.Location? {
        if let stationCode = soundingList.stationCodeByStationId[stationId],
           let matchingLocation = locations.first(where: { $0.name.caseInsensitiveCompare(stationCode) == .orderedSame }) {
            return matchingLocation
        }
        
        return locations.first
    }
    
    private var searchSuggestionLocations: [LocationList.Location] {
        guard soundingOrForecast == .sounding,
              !searchText.isEmpty,
              let locationList = try? LocationList.forType(.sounding) else {
            return []
        }
        
        return locationList.locationsForSearch(searchText)
    }
    
    @ViewBuilder
    private var forecastSelectionView: some View {
        Menu {
            Picker("Model", selection: $forecastModel) {
                ForEach(SoundingSelection.ForecastModel.allCases, id: \.self) {
                    Text($0.description)
                }
            }
        } label: {
            HStack {
                Text("Model: \(forecastModel.description)")
                    .padding([.horizontal])
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding([.horizontal, .bottom])
        .buttonStyle(.glass)
        .onChange(of: forecastModel) { _, newForecastModel in
            let modelType = store.state.currentSoundingState.selection.type
            
            guard case .forecast = modelType,
                  modelType.forecastModel != newForecastModel else {
                return
            }

            store.dispatch(
                SoundingState.Action.selection(
                    SoundingSelection.Action.selectModelTypeAndLocation(
                        .forecast(newForecastModel),
                        location,
                        .now
                    )
                )
            )
        }
        
        List {
            if !searchText.isEmpty {
                searchResultRows
            }
            
            if searchText.isEmpty {
                if store.state.locationState.locationIfKnown != nil {
                    Section(header: sectionHeader(
                        image: Image(systemName:"location.fill"),
                        text: "Current location"
                    )) {
                        currentLocationView
                    }
                }
                                
                Section(header: sectionHeader(
                    image: Image(systemName:"map.fill"),
                    text: "Nearby locations"
                )) {
                    ForEach(forecastLocations, id: \.self) {
                        row(forLocation: $0)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .listStyle(.plain)
    }
    
    private func sectionHeader(image: Image, text: String) -> some View {
        HStack {
            // The blue rectangle is put into an overlay instead of fill/background
            //  to avoid SwiftUI hiding it when the header is pinned at the top.
            Rectangle()
                .frame(width: 50, height: 50)
                .shadow(color: .black, radius: 1, x: 1, y: 1)
                .overlay {
                    ZStack {
                        Rectangle()
                            .fill(.blue)
                        
                        image
                    }
                }
            Text(text)
                .minimumScaleFactor(0.6)
                .lineLimit(1, reservesSpace: false)
                .padding([.leading], 8)
        }
        .font(.title3)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding([.horizontal], 10)
        .listRowInsets(EdgeInsets())
        .shadow(color: .black, radius: 1, x: 1, y: 1)
        .foregroundStyle(.menuSectionHeaderText)
        .background(
            LinearGradient(
                colors: [.menuSectionHeaderGradient1, .menuSectionHeaderGradient2],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxHeight: 40)
        )
        .padding([.bottom], 5)
    }
    
    @ViewBuilder
    private var currentLocationView: some View {
        row(
            withContent: { Text("Current location") },
            subtitle: { EmptyView() },
            isChecked: location == .closest,
            tapAction: {
                guard location != .closest else {
                    onReturnToSelection?().self
                    return
                }
                
                location = .closest
                
                store.dispatch(
                    SoundingState.Action.selection(
                        SoundingSelection.Action.selectModelTypeAndLocation(
                            .forecast(forecastModel),
                            .closest,
                            .now
                        )
                    )
                )
            }
        )
    }
    
    @ViewBuilder
    private var searchResultRows: some View {
        ForEach(try! LocationList.forType(.forecast(.automatic)).locationsForSearch(searchText), id: \.self) {
            row(forLocation: $0)
        }
    }
    
    private func row<Content: View, Subtitle: View>(
        @ViewBuilder withContent content: () -> Content,
        @ViewBuilder subtitle: () -> Subtitle,
        isChecked: Bool = false,
        tapAction: (() -> Void)? = nil
    ) -> some View {
        HStack {
            VStack(alignment: .leading) {
                content()
                    .foregroundStyle(.menuTitle)
                    .font(.title3)
                
                subtitle()
                    .font(.footnote)
            }
                
            Spacer()
            
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.title3)
                    .foregroundStyle(.menuTitle)
                    .padding([.trailing], 4)
            }
        }
        .foregroundStyle(.white)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets([.vertical], 8)
        .shadow(color: .black, radius: 1, x: 1, y: 1)
        .padding([.horizontal], 14)
        .padding([.vertical], 8)
        .background {
            ZStack {
                Rectangle()
                    .foregroundStyle(Gradient(colors: [.menuItemGradient1, .menuItemGradient2]))
                Rectangle()
                    .stroke(Color("MenuBorder"), lineWidth: 2)
                    .shadow(color: .black, radius: 1, x: 1, y: 1)

            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            tapAction?()
        }
    }
    
    @ViewBuilder
    private func row(forLocation forecastLocation: LocationList.Location) -> some View {
        let rowLocation = SoundingSelection.Location.named(
            name: forecastLocation.name,
            latitude: forecastLocation.latitude,
            longitude: forecastLocation.longitude
        )
        
        row(withContent: { Text(forecastLocation.description) },
            subtitle: {
                if let ourCoordinate = store.state.locationState.locationIfKnown {
                    let ourLocation = CLLocation(latitude: ourCoordinate.latitude, longitude: ourCoordinate.longitude)
                    let thisLocation = CLLocation(latitude: forecastLocation.latitude, longitude: forecastLocation.longitude)
                    let distance = ourLocation.distance(from: thisLocation)
                    let bearing = ourCoordinate.bearing(toLocation: thisLocation.coordinate)
                    let distanceString = distanceFormatter.string(fromDistance: distance)
                    let bearingString = OrdinalDirection.closest(toBearing: bearing)
                    
                    HStack {
                        Text("\(distanceString) \(bearingString.abbreviation)")
                            .opacity(0.7)
                        
                        Image(systemName: "location.north.fill")
                            .foregroundColor(Color("DirectionalArrow"))
                            .rotationEffect(Angle(degrees: bearing))
                            .padding([.horizontal], 4)
                    }
                } else {
                    EmptyView()
                }
            },
            isChecked: location == rowLocation,
            tapAction: {
                guard location != rowLocation else {
                    onReturnToSelection?()
                    return
                }
                
                location = rowLocation
                
                if soundingOrForecast == .sounding,
                   let wmoId = forecastLocation.wmoId,
                   let soundingList = store.state.recentSoundings.soundingList,
                   soundingList.messagesByStationId[wmoId] == nil {
                    // There is no sounding from this location. We'll just move the map.
                    mapPosition = mapPosition(forLocation: forecastLocation)
                    searchText = ""
                    
                    return
                }
                
                store.dispatch(
                    SoundingState.Action.selection(
                        SoundingSelection.Action.selectModelTypeAndLocation(
                            modelTypeForSelection,
                            rowLocation,
                            .now
                        )
                    )
                )
            }
        )
    }
    
    private var modelTypeForSelection: SoundingSelection.ModelType {
        switch soundingOrForecast {
        case .sounding:
                .sounding
        case .forecast:
                .forecast(forecastModel)
        }
    }
        
    private var userPosition: MapCameraPosition {
        let location = store.state.locationState.locationIfKnown ?? .denver
        
        return .camera(
            MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                distance: MenuView.mapZoom
            )
        )
    }
    
    private var initialMapPosition: MapCameraPosition {
        let coordinate: CLLocationCoordinate2D
        
        switch store.state.currentSoundingState.selection.location {
        case .named(name: _, latitude: let latitude, longitude: let longitude),
                .point(latitude: let latitude, longitude: let longitude):
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        case .closest:
            let location = store.state.locationState.locationIfKnown ?? .denver
            coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        }
        
        return .camera(
            MapCamera(
                centerCoordinate: coordinate,
                distance: MenuView.mapZoom
            )
        )
    }
    
    private func mapPosition(forLocation location: LocationList.Location) -> MapCameraPosition {
        .camera(MapCamera(centerCoordinate: location.coordinate, distance: MenuView.mapZoom))
    }
    
    private var forecastLocations: [LocationList.Location] {
        let count = 10
        
        guard let locations = try? LocationList
            .forType(.forecast(.automatic))
            .locationsSortedByProximity(to: currentLocation) else {
            
            return []
        }
        
        return Array(locations.prefix(count))
    }
    
    private let distanceFormatter: MKDistanceFormatter = {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        
        return formatter
    }()
    
    private func configurePickerTypography() {
        #if os(iOS)
        let monospacedBody = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .regular
        )
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: monospacedBody,
            .foregroundColor: UIColor(Color.menuSectionHeaderText)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: monospacedBody,
            .foregroundColor: UIColor(Color.menuTitle)
        ]

        let appearance = UISegmentedControl.appearance()
        appearance.backgroundColor = UIColor(Color.menuItemGradient2).withAlphaComponent(0.2)
        appearance.selectedSegmentTintColor = UIColor(Color.menuSectionHeaderGradient1)
        appearance.setTitleTextAttributes(normalAttributes, for: .normal)
        appearance.setTitleTextAttributes(selectedAttributes, for: .selected)
        #endif
    }
    
    private var currentLocation: CLLocationCoordinate2D {
        store.state.locationState.locationIfKnown ?? .denver
    }

    private func selectLatestSounding(forLocation location: LocationList.Location) {
        store.dispatch(
            SoundingState.Action.selection(
                SoundingSelection.Action.selectModelTypeAndLocation(
                    .sounding,
                    .named(
                        name: location.name,
                        latitude: location.latitude,
                        longitude: location.longitude
                    ),
                    .now
                )
            )
        )
        
        onReturnToSelection?()
    }
    
    private func requestLocationForNearbyForecastsIfNeeded() {
        guard store.state.locationState.locationIfKnown == nil else {
            return
        }

        store.dispatch(LocationState.Action.requestLocation)
    }
}

fileprivate extension SoundingSelection.ModelType {
    var forecastModel: SoundingSelection.ForecastModel? {
        switch self {
        case .sounding:
            nil
        case .forecast(let model):
            model
        }
    }
}

#Preview {
    MenuView(onReturnToSelection: { return })
        .environmentObject(Store<SkewtState>.previewStore)
        .environment(\.appEnvironment, AppEnvironment(isLive: false))
        .fontDesign(.monospaced)
}
