//
//  ContentView.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store<State>
    
    var body: some View {
        AnnotatedSkewtPlotView().environmentObject(store)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
