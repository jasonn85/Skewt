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
    
    enum SoundingOrForecast {
        case sounding
        case forecast
    }
    
    var body: some View {
        VStack {
            Picker("Forecast or Sounding", selection: $soundingOrForecast) {
                Text("Forecast")
                    .tag(SoundingOrForecast.forecast)
                Text("Sounding")
                    .tag(SoundingOrForecast.sounding)
            }
            .pickerStyle(.segmented)
            
            if soundingOrForecast == .forecast {
                Menu("Model: \(forecastModel.description)") {
                    Picker("Model", selection: $forecastModel) {
                        ForEach(SoundingSelection.ForecastModel.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                }
                .buttonStyle(.glass)
                                
                List(forecastLocations, id: \.self) { forecastLocation in
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
            }
        }
        .onAppear {
            configurePickerTypography()
            
            forecastModel = store.state.currentSoundingState
                .selection.type.forecastModel ?? .automatic
            
            location = store.state.currentSoundingState.selection.location
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
    MenuView()
        .environmentObject(Store<SkewtState>.previewStore)
        .environment(\.appEnvironment, AppEnvironment(isLive: false))
}
