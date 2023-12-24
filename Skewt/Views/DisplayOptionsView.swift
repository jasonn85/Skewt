//
//  DisplayOptionsView.swift
//  Skewt
//
//  Created by Jason Neel on 5/30/23.
//

import SwiftUI

struct DisplayOptionsView: View {
    @EnvironmentObject var store: Store<SkewtState>
    static private let maximumAltitude = 40_000.0
    static private let minimumMaximumAltitude = 2_000.0
    static private let skewRange = 0.0...2.0
    
    @State private var lineStylesExpanded = false
    
    private var altitudeFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }
    
    private var topAltitude: Double {
        store.state.plotOptions.altitudeRange?.upperBound ?? Self.maximumAltitude
    }

    var body: some View {
        NavigationStack {
            List {
                Section() {
                    VStack {
                        HStack {
                            Text("Maximum altitude")
                            
                            Spacer()
                            
                            Text("\(altitudeFormatter.string(from: topAltitude as NSNumber)!) feet")
                        }
                        
                        Slider(
                            value: Binding<Double>(
                                get: { store.state.plotOptions.altitudeRange?.upperBound ?? Self.maximumAltitude },
                                set: {
                                    store.dispatch(PlotOptions.Action.changeAltitudeRange(0.0...$0))
                                }
                            ),
                            in: Self.minimumMaximumAltitude...Self.maximumAltitude,
                            step: 1_000.0
                        )
                    }
                    
                    VStack {
                        HStack {
                            Text("Skew")
                            Spacer()
                            Text(String(store.state.plotOptions.skew))
                        }
                        
                        Slider(
                            value: Binding<Double>(
                                get: { store.state.plotOptions.skew },
                                set: { store.dispatch(PlotOptions.Action.changeSkew($0)) }
                            ),
                            in: Self.skewRange,
                            step: 0.25
                        )
                    }
                }
                
                Section {
                    windBarbs
                    animatedWind
                }
                
                Section("Isopleths") {
                    isotherms
                    isobars
                    adiabats
                    mixingLines
                    isobarLabels
                    isothermLabels
                }
                
                Section {
                    lineStyles
                }
                
                Section("About") {
                    NavigationLink("Privacy policy") {
                        PrivacyPolicyView()
                    }
                        
                    Link(destination: URL(string: "https://github.com/jasonn85/Skewt")!) {
                        HStack(alignment: .center) {
                            Text("Skew-T² on GitHub")
                            Image(systemName: "safari")
                        }
                    }
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var windBarbs: some View {
        HStack {
            Rectangle()
                .border(.black, width: 1.0)
                .frame(width: 20.0, height: 20.0)
                .foregroundColor(.clear)
                .background {
                    WindBarb(bearingInDegrees: 45, speed: 75, length: 16.0, tickSpacing: 3.0, tickLength: 5.0)
                        .stroke(.red, lineWidth: 1.0)
                        .border(.black, width: 1.0)
                }
            
            Toggle(isOn: Binding<Bool>(get: {
                store.state.plotOptions.showWindBarbs
            }, set: { showWindBarbs in
                withAnimation {
                    store.dispatch(PlotOptions.Action.setWindBarbs(showWindBarbs))
                }
            })) {
                Text("Wind barbs")
            }
        }
    }
    
    @ViewBuilder
    private var animatedWind: some View {
        HStack {
            Rectangle()
                .border(.black, width: 1.0)
                .frame(width: 20.0, height: 20.0)
                .foregroundColor(.clear)
                .background {
                    GeometryReader { geometry in
                        ZStack {
                            Rectangle()
                                .foregroundColor(.white)
                            
                            BackgroundView(
                                frame: CGRect(origin: .zero, size: geometry.size),
                                winds: [0.5: -15.0],
                                skyColors: []
                            )
                        }
                    }
                }
                .clipped()
            
            Toggle(isOn: Binding<Bool>(get: {
                store.state.plotOptions.showAnimatedWind
            }, set: { showAnimatedWind in
                withAnimation {
                    store.dispatch(PlotOptions.Action.setShowAnimatedWind(showAnimatedWind))
                }
            })) {
                Text("Animated wind")
            }
        }
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
                    set: { type in
                        withAnimation {
                            store.dispatch(PlotOptions.Action.changeIsobarTypes(type))
                        }
                    }
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
                set: { isOn in
                    withAnimation {
                        store.dispatch(PlotOptions.Action.setIsobarLabels(isOn))
                    }
                }
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
                set: { isOn in
                    withAnimation {
                        store.dispatch(PlotOptions.Action.setIsothermLabels(isOn))
                    }
                }
            )) {
                Text("Isotherm labels")
            }
        }
    }
    
    @ViewBuilder
    private var lineStyles: some View {
        DisclosureGroup("Line styles", isExpanded: $lineStylesExpanded) {
            Grid {
                ForEach(PlotOptions.PlotStyling.PlotType.allCases, id: \.id) { lineType in
                    LineStyleView(
                        lineType: lineType,
                        lineStyle: Binding<PlotOptions.PlotStyling.LineStyle>(
                            get: { store.state.plotOptions.plotStyling.lineStyle(forType: lineType) },
                            set: { lineStyle in
                                if lineStyle == PlotOptions.PlotStyling.defaultStyle(forType: lineType) {
                                    store.dispatch(PlotOptions.PlotStyling.Action.setStyleToDefault(lineType))
                                } else {
                                    store.dispatch(PlotOptions.PlotStyling.Action.setStyle(lineType, lineStyle))
                                }
                            }
                        )
                    )
                    
                    if lineType != PlotOptions.PlotStyling.PlotType.allCases.last {
                        Divider()
                    }
                }
            }
        }
    }
}

struct DisplayOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        DisplayOptionsView().environmentObject(Store<SkewtState>.previewStore)
    }
}
