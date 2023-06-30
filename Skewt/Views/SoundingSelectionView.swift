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
    var mapSpan = 1.0
    var soundingDataMaxAge: TimeInterval = 5.0 * 60.0  // five minutes
    
    var body: some View {
        List {
            if store.state.pinnedSelections.count > 0 {
                Section("Pinned") {
                    ForEach(store.state.pinnedSelections, id: \.id) {
                        selectionRow($0)
                    }
                }
            }
            
            Section("Recent") {
                ForEach(store.state.recentSelections, id: \.id) {
                    selectionRow($0)
                }
            }
            
            Section("Nearby Locations") {
                Picker("Data type", selection: Binding<SoundingSelection.ModelType>(get: {
                    store.state.currentSoundingState.selection.type
                }, set: {
                    store.dispatch(SoundingState.Action.changeAndLoadSelection(.selectModelType($0)))
                })
                ) {
                    ForEach(SoundingSelection.ModelType.allCases, id: \.id) {
                       Text($0.briefDescription)
                    }
                }
                .pickerStyle(.segmented)
                
                locationList
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
    
    private var closestLocationsForCurrentModelType: [LocationList.Location] {
        var wmoIds: [Int]? = nil
        
        switch store.state.currentSoundingState.selection.type {
        case .op40:
            break
        case .raob:
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
        }
        
        let modelType = store.state.currentSoundingState.selection.type

        guard let locations = try? LocationList.forType(modelType) else {
            return []
        }

        return Array(locations.locationsSortedByProximity(to: centerLocation, onlyWmoIds: wmoIds)[..<locationListLength])
    }
    
    @ViewBuilder
    private var locationList: some View {
        ForEach(closestLocationsForCurrentModelType, id: \.name) {
            selectionRow(
                SoundingSelection(
                    type: store.state.currentSoundingState.selection.type,
                    location: .named($0.name),
                    time: .now
                ),
                friendlyName: "\($0.name) - \($0.description)"
            )
        }
    }
        
    private func selectionRow(_ selection: SoundingSelection, friendlyName: String? = nil) -> some View {
        HStack {
            Image(systemName: "checkmark")
                .foregroundColor(.blue)
                .opacity(store.state.currentSoundingState.selection == selection ? 1.0 : 0.0)
                .padding(.trailing)
            
            VStack(alignment: .leading) {
                Text(friendlyName ?? selection.location.briefDescription)
                
                Text(selection.type.briefDescription)
                    .font(.footnote)
            }
            
            Spacer()
            
            Toggle(
                isOn: Binding<Bool>(
                    get: { selectionIsPinned(selection) },
                    set: { isPinned in
                        withAnimation {
                            if isPinned {
                                store.dispatch(SkewtState.Action.pinSelection(selection))
                            } else {
                                store.dispatch(SkewtState.Action.unpinSelection(selection))
                            }
                        }
                    }
                )) {
                    Image(systemName: selectionIsPinned(selection) ? "pin.fill" : "pin")
                }
                .toggleStyle(.button)
        }
        .onTapGesture {
            withAnimation {
                store.dispatch(SoundingState.Action.changeAndLoadSelection(
                    .selectModelTypeAndLocation(
                        selection.type,
                        selection.location
                    )
                ))
            }
        }
    }
    
    private func selectionIsPinned(_ selection: SoundingSelection) -> Bool {
        store.state.pinnedSelections.contains(selection)
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
