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
    
    func testFromHex() {
        
    }
    
    func testToHex() {
        
    }
}
