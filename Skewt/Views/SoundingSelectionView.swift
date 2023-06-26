//
//  SoundingSelectionView.swift
//  Skewt
//
//  Created by Jason Neel on 6/15/23.
//

import SwiftUI

struct SoundingSelectionView: View {
    @EnvironmentObject var store: Store<SkewtState>
    @State private var searchText = ""
    
    var body: some View {
        List {
            if store.state.pinnedSelections.count > 0 {
                Section("Pinned") {
                    ForEach(store.state.pinnedSelections, id: \.id) {
                        selectionRow($0)
                    }
                }
            }
            
            Section("Recents") {
                ForEach(store.state.recentSelections, id: \.id) {
                    selectionRow($0)
                }
            }
            
            Section("Data type") {
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
            }
            
            Section("Location") {
                Text("TODO")
            }
        }
    }
    
    private func selectionRow(_ selection: SoundingSelection) -> some View {
        HStack {
            Image(systemName: "checkmark")
                .foregroundColor(.blue)
                .opacity(store.state.currentSoundingState.selection == selection ? 1.0 : 0.0)
                .padding(.trailing)
            
            VStack(alignment: .leading) {
                Text(selection.location.briefDescription)
                    .font(.title3)
                
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
