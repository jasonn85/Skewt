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
        let soundingData: SoundingData
        
        var id: String { "\(stationId)-\(location.name)" }
    }
    
    private static let soundingLocationsByWmoId: [Int: [LocationList.Location]] = LocationList.allLocations.locations
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
            if let onReturnToSelection = onReturnToSelection {
                HStack {
                    Spacer()
                    
                    Button {
                        onReturnToSelection()
                    } label: {
                        Image(systemName: "chevron.forward")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding([.horizontal])
                }
            }
            
            HStack {
                Picker("Forecast or Sounding", selection: $soundingOrForecast) {
                    Text("Forecast")
                        .tag(SoundingOrForecast.forecast)
                    Text("Sounding")
                        .tag(SoundingOrForecast.sounding)
                }
                .pickerStyle(.segmented)
            }
            .padding()
            
            switch soundingOrForecast {
            case .sounding:
                soundingSelectionView
            case .forecast:
                forecastSelectionView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText)
        .onAppear {
            configurePickerTypography()
            requestLocationForNearbyForecastsIfNeeded()
            
            forecastModel = store.state.currentSoundingState
                .selection.type.forecastModel ?? .automatic
            
            location = store.state.currentSoundingState.selection.location
        }
    }
    
    @ViewBuilder
    private var soundingSelectionView: some View {
        VStack {
            Map (initialPosition: initialMapPosition, interactionModes: [.pan, .zoom]) {
                ForEach(soundingAnnotationItems) { item in
                    Annotation(item.location.description, coordinate: item.location.coordinate, anchor: .bottom) {
                        SoundingMapAnnotation(data: item.soundingData)
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                selectLatestSounding(forLocation: item.location)
                            }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
            }
        }
    }
    
    private var soundingAnnotationItems: [SoundingAnnotationItem] {
        guard let soundingList = store.state.recentSoundings.soundingList else {
            return []
        }
        
        return soundingList.messagesByStationId.keys
            .sorted()
            .compactMap { stationId in
                guard let locations = Self.soundingLocationsByWmoId[stationId],
                      let representativeLocation = representativeSoundingLocation(
                        forStationId: stationId,
                        from: locations,
                        using: soundingList
                      ),
                      let soundingData = soundingList.soundingData(forStationId: stationId) else {
                    return nil
                }
                
                return SoundingAnnotationItem(
                    stationId: stationId,
                    location: representativeLocation,
                    soundingData: soundingData
                )
            }
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
                    Section {
                        currentLocationView
                    }
                }
                
                Section("Nearby locations") {
                    ForEach(forecastLocations, id: \.self) {
                        row(forLocation: $0)
                    }
                }
            }
        }
        .listSectionSpacing(.compact)
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var currentLocationView: some View {
        HStack {
            Image(systemName: store.state.currentSoundingState.selection.location == .closest
                  ? "location.fill"
                  : "location")
                .foregroundStyle(.blue)
            
            Text("Current location")
            
            Spacer()
            
            if location == .closest {
                Image(systemName: "checkmark")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
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
    }
    
    @ViewBuilder
    private var searchResultRows: some View {
        ForEach(try! LocationList.forType(.forecast(.automatic)).locationsForSearch(searchText), id: \.self) {
            row(forLocation: $0)
        }
    }
    
    @ViewBuilder
    private func row(forLocation forecastLocation: LocationList.Location) -> some View {
        let rowLocation = SoundingSelection.Location.named(
            name: forecastLocation.name,
            latitude: forecastLocation.latitude,
            longitude: forecastLocation.longitude
        )

        VStack {
            HStack {
                Text(forecastLocation.description)
                
                Spacer()
                
                if location == rowLocation {
                    Image(systemName: "checkmark")
                }
            }
            
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
                    
                    Spacer()
                }
                .font(.footnote)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard location != rowLocation else {
                return
            }
            
            location = rowLocation
            
            store.dispatch(
                SoundingState.Action.selection(
                    SoundingSelection.Action.selectModelTypeAndLocation(
                        .forecast(forecastModel),
                        rowLocation,
                        .now
                    )
                )
            )
        }
    }
    
    private var initialMapPosition: MapCameraPosition {
        let location = store.state.locationState.locationIfKnown ?? .denver
        
        return .camera(
            MapCamera(
                centerCoordinate: location,
                distance: 1_000_000  // 1,000 km
            )
        )
    }
    
    private var forecastLocations: [LocationList.Location] {
        let count = 10
        
        guard let locations = try? LocationList.forType(.sounding).locationsSortedByProximity(to: currentLocation) else {
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
        let attributes: [NSAttributedString.Key: Any] = [.font: monospacedBody]

        UISegmentedControl.appearance().setTitleTextAttributes(attributes, for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes(attributes, for: .selected)
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
