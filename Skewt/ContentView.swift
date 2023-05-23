//
//  ContentView.swift
//  Skewt
//
//  Created by Jason Neel on 2/15/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store<SkewtState>
    
    var body: some View {
        VStack {
            Text("It's a graph!")

            AnnotatedSkewtPlotView().environmentObject(store).onAppear() {
                store.dispatch(LocationState.Action.requestLocation)
            }

            Group {
                Toggle("Altitude labels", isOn: Binding<Bool>(
                    get: { store.state.plotOptions.showIsobarLabels },
                    set: { store.dispatch(PlotOptions.Action.setIsobarLabels($0)) }
                ))

                Toggle("Temperature labels", isOn: Binding<Bool>(
                    get: { store.state.plotOptions.showIsothermLabels },
                    set: { store.dispatch(PlotOptions.Action.setIsothermLabels($0)) }
                ))
            }.padding(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

            Spacer()
        }
        .pickerStyle(.segmented)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environmentObject(Store<SkewtState>.previewStore)
    }
}
