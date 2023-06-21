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
            Section("Pinned") {
                
            }
            
            Section("Recents") {
                VStack {
                    Text("Current location").font(.title3)
                    Text("op40 forecast")
                        .font(.footnote)
                }
                
                VStack {
                    Text("Current location").font(.title3)
                    Text("sounding")
                        .font(.footnote)
                }
            }
            
            Section("Data type") {
                Picker("Data type", selection: $modelType) {
                    ForEach(SoundingSelection.ModelType.allCases, id: \.id) {
                        Text($0.briefDescription)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("Location") {
                
            }
            
            // map here and stuff
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
