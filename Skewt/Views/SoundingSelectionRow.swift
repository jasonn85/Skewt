//
//  SoundingSelectionRow.swift
//  Skewt
//
//  Created by Jason Neel on 7/2/23.
//

import SwiftUI

struct SoundingSelectionRow: View {
    @EnvironmentObject var store: Store<SkewtState>
    var selection: SoundingSelection
    var friendlyName: String?
    
    var body: some View {
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

struct SoundingSelectionRow_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore
        
        ForEach(store.state.pinnedSelections, id: \.id) {
            SoundingSelectionRow(selection: $0)
                .environmentObject(store)
        }
        
        ForEach(store.state.recentSelections, id: \.id) {
            SoundingSelectionRow(selection: $0)
                .environmentObject(store)
        }
    }
}
