//
//  MenuView.swift
//  Skewt
//
//  Created by Jason Neel on 2/24/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct MenuView: View {
    @EnvironmentObject var store: Store<SkewtState>

    @State private var soundingOrForecast = SoundingOrForecast.forecast
    @State private var forecastModel = SoundingSelection.ForecastModel.automatic
    
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
                
            }
        }
        .onAppear {
            configurePickerTypography()
            
            forecastModel = store.state.currentSoundingState
                .selection.type.forecastModel ?? .automatic
        }
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
