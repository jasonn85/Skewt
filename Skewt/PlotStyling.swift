//
//  PlotStyling.swift
//  Skewt
//
//  Created by Jason Neel on 6/1/23.
//

import Foundation
import CoreGraphics
import SwiftUI

extension PlotOptions.PlotStyling {
    func lineStyle(forType type: PlotType) -> LineStyle {
        return lineStyles[type] ?? Self.defaultStyle(forType: type)
    }
    
    static func defaultStyle(forType type: PlotType) -> LineStyle {
        // Standard defaults
        var width: CGFloat = 1.0
        var color = UIColor.red
        var dashed = false
        
        switch type {
        case .temperature:
            width = 3.0
            color = UIColor(named: "TemperaturePlot")!
        case .dewPoint:
            width = 3.0
            color = UIColor(named: "DewPointPlot")!
        case .isotherms:
            color = UIColor(named: "IsothermPlot")!
        case .zeroIsotherm:
            width = 2.0
            color = UIColor(named: "ZeroIsothermPlot")!
        case .altitudeIsobars, .pressureIsobars:
            color = UIColor(named: "IsobarPlot")!
        case .dryAdiabats:
            color = UIColor(named: "DryAdiabatPlot")!
        case .moistAdiabats:
            color = UIColor(named: "MoistAdiabatPlot")!
        }
        
        let textColor = color.cgColor.rgbHexString!
        let opacity = color.cgColor.alpha
        
        return LineStyle(
            lineWidth: width,
            color: textColor,
            opacity: opacity,
            dashed: dashed
        )
    }
}

extension CGColor {
    /// Hex string e.g. "#BAD123" for an RGB color. Nil for non-RGB.
    var rgbHexString: String? {
        guard colorSpace?.model == .rgb,
                numberOfComponents >= 3,
                let components = components else {
            return nil
        }
        
        let red = Int(components[0] * 255.0)
        let green = Int(components[1] * 255.0)
        let blue = Int(components[2] * 255.0)
        
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
    
    static func fromHex(hexString: String) -> CGColor? {
        let justHex = hexString.suffix(6).trimmingCharacters(
            in: CharacterSet(charactersIn: "1234567890ABCDEFabcdef").inverted
        )
        
        guard justHex.count == 6 else {
            return nil
        }
        
        let red = "0x" + String(justHex.prefix(2))
        let green = "0x" + String(justHex.suffix(4).prefix(2))
        let blue = "0x" + String(justHex.suffix(2))
        
        var redValue: Double = 0
        var greenValue: Double = 0
        var blueValue: Double = 0
        
        Scanner(string: red).scanHexDouble(&redValue)
        Scanner(string: green).scanHexDouble(&greenValue)
        Scanner(string: blue).scanHexDouble(&blueValue)

        return CGColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
    }
}
