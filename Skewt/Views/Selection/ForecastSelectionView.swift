//
//  ForecastSelectionView.swift
//  Skewt
//
//  Created by Jason Neel on 7/2/23.
//

import SwiftUI

struct ForecastSelectionView: View {
    var body: some View {
        Text("TODO")
    }
}

struct ForecastSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let store = Store<SkewtState>.previewStore

        ForecastSelectionView()
            .environmentObject(store)
    }
}
