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
                    SoundingSelectionRow(selection: $0, subtitleComponents: [.type])
                        .environmentObject(store)
                }
            }
            
            Section("Recent") {
                ForEach(store.state.recentSelections, id: \.id) {
                    SoundingSelectionRow(selection: $0, subtitleComponents: [.type])
                        .environmentObject(store)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct RecentSelectionsView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore

        RecentSelectionsView()
            .environmentObject(store)
    }
}
