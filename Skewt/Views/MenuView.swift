//
//  MenuView.swift
//  Skewt
//
//  Created by Jason Neel on 2/24/26.
//

import SwiftUI
import CoreLocation
#if os(iOS)
import UIKit
#endif

struct MenuView: View {
    @EnvironmentObject var store: Store<SkewtState>

    @State private var soundingOrForecast = SoundingOrForecast.forecast
    @State private var forecastModel = SoundingSelection.ForecastModel.automatic
    @State private var location = SoundingSelection.Location.closest
    let onReturnToSelection: (() -> Void)?
    
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
                // TODO: this
                EmptyView()
            case .forecast:
                forecastSelectionView
            }
        }
        .onAppear {
            configurePickerTypography()
            requestLocationForNearbyForecastsIfNeeded()
            
            forecastModel = store.state.currentSoundingState
                .selection.type.forecastModel ?? .automatic
            
            location = store.state.currentSoundingState.selection.location
        }
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
        .listSectionSpacing(.compact)
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private var currentLocationView: some View {
        HStack {
            Image(systemName: "location.fill")
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
    private func row(forLocation forecastLocation: LocationList.Location) -> some View {
        let rowLocation = SoundingSelection.Location.named(
            name: forecastLocation.name,
            latitude: forecastLocation.latitude,
            longitude: forecastLocation.longitude
        )

        HStack {
            Text(forecastLocation.description)
            
            Spacer()
            
            if location == rowLocation {
                Image(systemName: "checkmark")
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
    
    private var forecastLocations: [LocationList.Location] {
        let count = 10
        
        guard let locations = try? LocationList.forType(.sounding).locationsSortedByProximity(to: currentLocation) else {
            return []
        }
        
        return Array(locations.prefix(count))
    }
    
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
