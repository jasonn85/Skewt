//
//  PlotStylingTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 6/1/23.
//

import XCTest
@testable import Skewt

final class PlotStylingTests: XCTestCase {

    func testDefaultColors() {
        let styling = PlotOptions.PlotStyling()
        
        PlotOptions.PlotStyling.PlotType.allCases.forEach {
            XCTAssertEqual(styling.lineStyle(forType: $0), PlotOptions.PlotStyling.defaultStyle(forType: $0))
        }
    }
    
    func testNonDefaultStylesApplied() {
        let crazyStyle = PlotOptions.PlotStyling.LineStyle(
            active: true,
            lineWidth: 69.0,
            color: "#69AB42",
            opacity: 0.69,
            dashed: true
        )
        
        PlotOptions.PlotStyling.PlotType.allCases.forEach {
            let style = PlotOptions.PlotStyling(lineStyles: [$0: crazyStyle])
            XCTAssertEqual(style.lineStyle(forType: $0), crazyStyle)
        }
    }
    
    func testInactiveStyles() {
        let type = PlotOptions.PlotStyling.PlotType.temperature
        let style = PlotOptions.PlotStyling.LineStyle(active: true, lineWidth: 2.0, color: "#123456", opacity: 0.75, dashed: true)
        var inactiveStyle = style
        inactiveStyle.active = false
        
        let styles = PlotOptions.PlotStyling(lineStyles: [type: style])
        XCTAssertEqual(styles.lineStyle(forType: type), style)
        
        let stylesWithDeactivated = PlotOptions.PlotStyling.reducer(styles, PlotOptions.PlotStyling.Action.setStyleToDefault(type))
        XCTAssertNotEqual(stylesWithDeactivated.lineStyle(forType: type), style)
        XCTAssertEqual(stylesWithDeactivated.lineStyle(forType: type, includeInactive: true), inactiveStyle)
    }
    
    func testFromHex() {
        let redHex = "#FF0000"
        let blackHex = "#000000"
        let greenHexNoHash = "00FF00"
        let cyanHex = "#00FFFF"
        let blueHex = "#0000FF"
        let lightBlueHex = "#0080FF"
        
        let red = CGColor.fromHex(hexString: redHex)!
        XCTAssertEqual(red.components![0], 1.0)
        XCTAssertEqual(red.components![1], 0.0)
        XCTAssertEqual(red.components![2], 0.0)

        let black = CGColor.fromHex(hexString: blackHex)!
        XCTAssertEqual(black.components![0], 0.0)
        XCTAssertEqual(black.components![1], 0.0)
        XCTAssertEqual(black.components![2], 0.0)
        
        let green = CGColor.fromHex(hexString: greenHexNoHash)!
        XCTAssertEqual(green.components![0], 0.0)
        XCTAssertEqual(green.components![1], 1.0)
        XCTAssertEqual(green.components![2], 0.0)
        
        let cyan = CGColor.fromHex(hexString: cyanHex)!
        XCTAssertEqual(cyan.components![0], 0.0)
        XCTAssertEqual(cyan.components![1], 1.0)
        XCTAssertEqual(cyan.components![2], 1.0)
        
        let blue = CGColor.fromHex(hexString: blueHex)!
        XCTAssertEqual(blue.components![0], 0.0)
        XCTAssertEqual(blue.components![1], 0.0)
        XCTAssertEqual(blue.components![2], 1.0)
        
        let lightBlue = CGColor.fromHex(hexString: lightBlueHex)!
        XCTAssertEqual(lightBlue.components![0], 0.0)
        XCTAssertEqual(lightBlue.components![1], 0.5, accuracy: 0.01)
        XCTAssertEqual(lightBlue.components![2], 1.0)
    }
    
    func testToHex() {
        let red = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let green = CGColor(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0)
        let blue = CGColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)
        
        XCTAssertEqual(red.rgbHexString!.uppercased(), "#FF0000")
        XCTAssertEqual(green.rgbHexString!.uppercased(), "#00FF00")
        XCTAssertEqual(blue.rgbHexString!.uppercased(), "#0000FF")
    }
}
