//
//  LineStyleView.swift
//  Skewt
//
//  Created by Jason Neel on 6/5/23.
//

import SwiftUI

extension PlotOptions.PlotStyling.PlotType: CustomStringConvertible {
    var description: String {
        switch self {
        case .temperature:
            return "Temperature"
        case .dewPoint:
            return "Dew point"
        case .isotherms:
            return "Isotherms"
        case .zeroIsotherm:
            return "0º isotherm"
        case .altitudeIsobars:
            return "Altitude isobars"
        case .pressureIsobars:
            return "Pressure isobars"
        case .dryAdiabats:
            return "Dry adiabats"
        case .moistAdiabats:
            return "Moist adiabats"
        case .isohumes:
            return "Mixing lines"
        }
    }
}

struct LineStyleView: View {
    let lineType: PlotOptions.PlotStyling.PlotType
    @Binding var lineStyle: PlotOptions.PlotStyling.LineStyle
    
    var body: some View {
        HStack {
            VStack {
                Text(lineType.description)
                
                Rectangle()
                    .foregroundColor(.clear)
                    .border(.black)
                    .aspectRatio(1.0, contentMode: .fit)
                    .frame(maxHeight: 32)
                    .background {
                        GeometryReader { geometry in
                            Path { path in
                                path.move(to: CGPoint(x: 0.0, y: geometry.size.height))
                                path.addLine(to: CGPoint(x: geometry.size.width, y: 0.0))
                            }
                            .applyLineStyle(lineStyle)
                        }
                    }
            }
            
            Spacer()
            Divider()
            Spacer()
                        
            VStack {
                Text("Default").font(.footnote)
                Toggle("Default", isOn: Binding<Bool>(
                    get: { !lineStyle.active },
                    set: { lineStyle.active = !$0 }
                ))
                .labelsHidden()
            }
            
            Spacer()
            Divider()
            Spacer()
            
            let twoColumns = [GridItem(.flexible()), GridItem(.flexible(minimum: 70))]
            
            LazyVGrid(columns: twoColumns) {
                Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                Stepper(
                    "Width",
                    value: $lineStyle.lineWidth,
                    in: 1.0...10.0,
                    step: 1.0
                )
                .lineLimit(1)
                .labelsHidden()
            
                Image(systemName: "paintpalette")
                ColorPicker("Color", selection: Binding<CGColor>(
                    get: { CGColor.fromHex(hexString: lineStyle.color,
                                           alpha: lineStyle.opacity)! },
                    set: {
                        lineStyle.color = $0.rgbHexString!
                        lineStyle.opacity = $0.alpha
                    }
                ))
                .labelsHidden()

                Image(systemName: "square.dashed")
                Toggle("Dashed", isOn: $lineStyle.dashed)
                    .labelsHidden()
            }
            .opacity(lineStyle.active ? 1.0 : 0.66)
            
            Spacer(minLength: 20.0)
        }
    }
}

struct LineStyleView_Previews: PreviewProvider {
    static var previewStore: Store<SkewtState> {
        let store = Store<SkewtState>.previewStore
        let nonDefaultStyle = PlotOptions.PlotStyling.LineStyle(active: true, lineWidth: 2.0, color: "##ec03fc", opacity: 0.8, dashed: true)
        store.dispatch(PlotOptions.PlotStyling.Action.setStyle(.dewPoint, nonDefaultStyle))
        
        return store
    }
    
    static var previews: some View {
        let store = previewStore
        let typesToShow: [PlotOptions.PlotStyling.PlotType] = [.temperature, .dewPoint]
        
        List {
            ForEach(typesToShow, id: \.id) { lineType in
                LineStyleView(
                    lineType: lineType,
                    lineStyle: Binding<PlotOptions.PlotStyling.LineStyle>(
                        get: { store.state.plotOptions.plotStyling.lineStyle(forType: lineType) },
                        set: {
                            if !$0.active {
                                store.dispatch(PlotOptions.PlotStyling.Action.setStyleToDefault(lineType))
                            } else {
                                store.dispatch(PlotOptions.PlotStyling.Action.setStyle(lineType, $0))
                            }
                        }
                    )
                )
            }
        }
    }
}
