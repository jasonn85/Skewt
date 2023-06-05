//
//  DisplayOptionsView.swift
//  Skewt
//
//  Created by Jason Neel on 5/30/23.
//

import SwiftUI

struct DisplayOptionsView: View {
    @EnvironmentObject var store: Store<SkewtState>

    var body: some View {
        List {
            Section("Range") {
                VStack {
                    Text("Altitude range")
                    Text("--slider here--").font(Font.system(size: 14.0))
                }
            }
            
            Section("Isopleths") {
                isotherms
                isobars
                adiabats
                mixingLines
                isobarLabels
                isothermLabels
            }
            
            Section("Line styles") {
                ForEach(PlotOptions.PlotStyling.PlotType.allCases, id: \.id) {
                    lineStyle(forType: $0)
                }
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var isotherms: some View {
        HStack {
            Image("logoIsotherms")
            
            Text("Isotherms")
                            
            Picker("Isotherms",
                   selection: Binding<PlotOptions.IsothermTypes>(
                    get: { store.state.plotOptions.isothermTypes },
                    set: { store.dispatch(PlotOptions.Action.changeIsothermTypes($0)) }
                   )) {
                    ForEach(PlotOptions.IsothermTypes.allCases, id: \.id) {
                        switch $0 {
                        case .none:
                            Text("none")
                        case .tens:
                            Text("10s")
                        case .zeroOnly:
                            Text("only 0")
                        }
                    }
                   }
        }
    }
    
    private var isobars: some View {
        HStack {
            Image("logoIsobars")
            
            Text("Isobars")
            
            Picker("Isobars",
                   selection: Binding<PlotOptions.IsobarTypes>(
                    get: { store.state.plotOptions.isobarTypes },
                    set: { store.dispatch(PlotOptions.Action.changeIsobarTypes($0)) }
                   )) {
                       ForEach(PlotOptions.IsobarTypes.allCases, id: \.id) {
                           switch $0 {
                           case .none:
                               Text("none")
                           case .altitude:
                               Text("altitude")
                           case .pressure:
                               Text("pressure")
                           }
                       }
                   }
        }
    }
    
    private var adiabats: some View {
        HStack {
            Image("logoAdiabats")
            
            Text("Adiabats")
            
            Picker("Adiabats",
                   selection: Binding<PlotOptions.AdiabatTypes>(
                    get: { store.state.plotOptions.adiabatTypes },
                    set: { store.dispatch(PlotOptions.Action.changeAdiabatTypes($0)) }
                   )) {
                       ForEach(PlotOptions.AdiabatTypes.allCases, id: \.id) {
                           switch $0 {
                           case .none:
                               Text("none")
                           case .tens:
                               Text("tens")
                           }
                       }
                   }
        }
    }
    
    private var mixingLines: some View {
        HStack {
            Image("logoIsohumes")
            
            Toggle(isOn: Binding<Bool>(
                get: { store.state.plotOptions.showMixingLines },
                set: { store.dispatch(PlotOptions.Action.setMixingLines($0)) }
            )) {
                Text("Mixing lines")
            }
        }
    }
    
    private var isobarLabels: some View {
        HStack {
            Image("logoYLabels")
            
            Toggle(isOn: Binding<Bool>(
                get: { store.state.plotOptions.showIsobarLabels },
                set: { store.dispatch(PlotOptions.Action.setIsobarLabels($0)) }
            )) {
                Text("Isobar labels")
            }
        }
    }
    
    private var isothermLabels: some View {
        HStack {
            Image("logoXLabels")
            
            Toggle(isOn: Binding<Bool>(
                get: { store.state.plotOptions.showIsothermLabels },
                set: { store.dispatch(PlotOptions.Action.setIsothermLabels($0)) }
            )) {
                Text("Isotherm labels")
            }
        }
    }
    
    func lineStyle(forType type: PlotOptions.PlotStyling.PlotType) -> some View {
        // TODO
        EmptyView()
    }
}

struct DisplayOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayOptionsView().environmentObject(Store<SkewtState>.previewStore)
    }
}
