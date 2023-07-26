//
//  RecentSelectionsView.swift
//  Skewt
//
//  Created by Jason Neel on 7/2/23.
//

import SwiftUI

struct RecentSelectionsView: View {
    @EnvironmentObject var store: Store<SkewtState>
    
    var body: some View {
        List {
            Section("Pinned") {
                ForEach(store.state.pinnedSelections, id: \.id) {
                    SoundingSelectionRow(
                        selection: $0,
                        titleComponents: titleComponents(forSelection: $0),
                        subtitleComponents: [.type]
                    )
                        .environmentObject(store)
                }
            }
            
            Section("Recent") {
                ForEach(store.state.recentSelections, id: \.id) {
                    SoundingSelectionRow(
                        selection: $0,
                        titleComponents: titleComponents(forSelection: $0),
                        subtitleComponents: [.type]
                    )
                        .environmentObject(store)
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func titleComponents(
        forSelection selection: SoundingSelection
    ) -> [SoundingSelectionRow.DescriptionComponent] {
        guard case .named(let stationName) = selection.location,
              let location = LocationList.allLocations.locationNamed(stationName) else {
            return [.selectionDescription]
        }
        
        return [.text(location.name), .text(location.description)]
    }
}

struct RecentSelectionsView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore

        RecentSelectionsView()
            .environmentObject(store)
    }
}
