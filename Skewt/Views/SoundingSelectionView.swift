//
//  SoundingSelectionView.swift
//  Skewt
//
//  Created by Jason Neel on 6/15/23.
//

import SwiftUI

struct SoundingSelectionView: View {
    @State var modelType: SoundingSelection.ModelType = .op40
    @State private var searchText = ""
    
    var body: some View {
        List {
            Section("Data type") {
                Picker("Data type", selection: $modelType) {
                    ForEach(SoundingSelection.ModelType.allCases, id: \.id) {
                        Text($0.briefDescription)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Location") {
                Text("Closest")
                Text("Somewhere else")
            }

            Section("Recents") {
                Text("Recent 1")
                Text("Recent 2")
            }
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
        SoundingSelectionView()
    }
}
