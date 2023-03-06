//
//  SkewTPlotTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 3/3/23.
//

import XCTest
@testable import Skewt

extension CGPath {
    /// Tests that all linear pieces of the path draw a positive slope.
    /// Ignores curved elements.
    var isPositiveSlope: Bool {
        var points: [CGPoint] = []
                
        applyWithBlock {
            let element = $0.pointee
            
            guard element.type == .moveToPoint || element.type == .addLineToPoint else {
                return
            }
            
            let point = Array(UnsafeBufferPointer(start: element.points, count: 1))[0]
            points.append(point)
        }
        
        var lastX = -CGFloat.infinity
        
        for point in points.sorted(by: { $0.y > $1.y }) {
            if point.x <= lastX {
                return false
            }
            
            lastX = point.x
        }
        
        return true
    }
}

final class SkewTPlotTests: XCTestCase {
    var sounding: Sounding!
    
    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "ord-gfs-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        sounding = try Sounding(fromText: s)
    }
    
    func testNilSoundingMakesNilPaths() {
        let size = CGSize(width: 100.0, height: 100.0)
        let plot = SkewtPlot(sounding: nil, size: size)
        XCTAssertNil(plot.temperaturePath, "No data generates a nil temperature path")
        XCTAssertNil(plot.dewPointPath, "No data generates a nil dew point path")
    }

    func testPlottablePointsMakePath() throws {
        let size = CGSize(width: 100.0, height: 100.0)
        let plot = SkewtPlot(sounding: sounding, size: size)
        
        XCTAssertFalse(plot.temperaturePath!.isEmpty, "Data generates a path for temperature")
        XCTAssertFalse(plot.dewPointPath!.isEmpty, "Data generates a path for dew point")
        XCTAssertTrue(plot.temperaturePath!.boundingBox.size.width > 0)
        XCTAssertTrue(plot.temperaturePath!.boundingBox.size.height > 0)
        XCTAssertTrue(plot.dewPointPath!.boundingBox.size.width > 0)
        XCTAssertTrue(plot.dewPointPath!.boundingBox.size.height > 0)
    }
    
    func testConstantTemperatureSlopesRight() throws {
        let constantTempSounding = try Sounding(fromText: """
RAOB sounding valid at:
   RAOB     12     22      FEB    2023
      1   3190  72293  32.87N117.15W   134   1103
      2     70   1370   1120    181  72293      3
      3           NKX                99999     kt   HHMM bearing  range
      5   8270   1602    -20    -40  99999  99999   1119  99999  99999
      5   6000   4124    -20    -40  99999  99999   1120  99999  99999
      5   4000   7186    -20    -40  99999  99999   1120  99999  99999
      5   2000  11879    -20    -40  99999  99999   1120  99999  99999
      5   1000  16212    -20    -40  99999  99999   1120  99999  99999
""")
        let plot = SkewtPlot(sounding: constantTempSounding, size: CGSize(width: 100.0, height: 100.0))
        
        XCTAssertTrue(plot.temperaturePath!.isPositiveSlope)
    }
    
    func testIsobarNonLinearScale() {
        let height = 100.0
        let plot = SkewtPlot(sounding: sounding, size: CGSize(width: height, height: height))
        let sortedIsobars = plot.isobarPaths.sorted(by: { $0.boundingBox.origin.y > $1.boundingBox.origin.y })
        
        var lastY = height
        var lastDy = 0.0
        
        sortedIsobars[1...].forEach {
            let y = $0.boundingBox.origin.y
            let dy = lastY - y
            XCTAssertTrue(dy > lastDy)  // Each isobar is farther than the last
            
            lastDy = dy
            lastY = y
        }
    }
    
    func testIsothermGeneration() {
        let squarePlot = SkewtPlot(sounding: sounding, size: CGSize(width: 100.0, height: 100.0))
        
        let bottomLeft = CGPoint(x: 0.0, y: 100.0)
        let squareTopRight = CGPoint(x: 100.0, y: 0.0)
        let middleBottom = CGPoint(x: 50.0, y: 100.0)
        let middleLeft = CGPoint(x: 0.0, y: 50.0)
        let middleRight = CGPoint(x: 100.0, y: 50.0)
        let middleTop = CGPoint(x: 50.0, y: 0.0)
        let (_, bottomLeftTemp) = squarePlot.pressureAndTemperature(atPoint: bottomLeft)
        let fullLine = squarePlot.isotherm(forTemperature: bottomLeftTemp)
        let (_, middleTemp) = squarePlot.pressureAndTemperature(atPoint: middleBottom)
        let halfAcrossLine = squarePlot.isotherm(forTemperature: middleTemp)
        let (_, halfOffLeftTemp) = squarePlot.pressureAndTemperature(atPoint: CGPoint(x: -50.0, y: 100.0))
        let halfOffLeftLine = squarePlot.isotherm(forTemperature: halfOffLeftTemp)
        
        XCTAssertEqual(fullLine.0, bottomLeft)
        XCTAssertEqual(fullLine.1, squareTopRight)
        XCTAssertEqual(halfAcrossLine.0, middleBottom)
        XCTAssertEqual(halfAcrossLine.1, middleRight)
        XCTAssertEqual(halfOffLeftLine.0, middleLeft)
        XCTAssertEqual(halfOffLeftLine.1, middleTop)
        
        let skewedUpSquarePlot = SkewtPlot(sounding: sounding, size: CGSize(width: 100.0, height: 100.0), surfaceTemperatureRange: squarePlot.surfaceTemperatureRange, pressureRange: squarePlot.pressureRange, isothermSpacing: squarePlot.isothermSpacing, adiabatSpacing: squarePlot.adiabatSpacing, isobarSpacing: squarePlot.isothermSpacing, skewSlope: 2.0)
        let steepFromBottomLeft = skewedUpSquarePlot.isotherm(forTemperature: bottomLeftTemp)
        let steepFromBottomMiddle = skewedUpSquarePlot.isotherm(forTemperature: middleTemp)
        XCTAssertEqual(steepFromBottomLeft.0, bottomLeft)
        XCTAssertEqual(steepFromBottomLeft.1, middleTop)
        XCTAssertEqual(steepFromBottomMiddle.0, middleBottom)
        XCTAssertEqual(steepFromBottomMiddle.1, squareTopRight)
        
        let skewedDownSquarePlot = SkewtPlot(sounding: sounding, size: CGSize(width: 100.0, height: 100.0), surfaceTemperatureRange: squarePlot.surfaceTemperatureRange, pressureRange: squarePlot.pressureRange, isothermSpacing: squarePlot.isothermSpacing, adiabatSpacing: squarePlot.adiabatSpacing, isobarSpacing: squarePlot.isothermSpacing, skewSlope: 0.5)
        let shallowFromBottomLeft = skewedDownSquarePlot.isotherm(forTemperature: bottomLeftTemp)
        XCTAssertEqual(shallowFromBottomLeft.0, bottomLeft)
        XCTAssertEqual(shallowFromBottomLeft.1, middleRight)
    }
    
    func testIsothermSkew() {
        let plot = SkewtPlot(sounding: sounding, size: CGSize(width: 100.0, height: 100.0))
        
        XCTAssertTrue(plot.isothermPaths.count > 0)
        
        plot.isothermPaths.forEach {
            XCTAssertTrue($0.isPositiveSlope, "Slope of isotherm should be positive: \(String(describing: $0))")
        }
    }
    
    /// A roughly square plot should have twice as many isotherms as fill the X axis
    func testIsothermCount() {
        let plot = SkewtPlot(sounding: sounding, size: CGSize(width: 100.0, height: 100.0))
        let singleAxisCount = Int((plot.surfaceTemperatureRange.upperBound
                                   - plot.surfaceTemperatureRange.lowerBound)
                                  / plot.isothermSpacing)
        let expectedCount = (singleAxisCount * 2 - 2)...(singleAxisCount * 2 + 2)
        
        XCTAssertTrue(expectedCount.contains(plot.isothermPaths.count),
                      "Expecting \(String(describing: expectedCount)) isotherms, found \(plot.isobarPaths.count)")
    }
    
    func testDataToCoordinateAndBack() {
        let plot = SkewtPlot(sounding: sounding, size: CGSize(width: 100.0, height: 100.0))

        let data = sounding.data.filter({ $0.isPlottable }).first!
        let expected = (pressure: data.pressure, temperature: data.temperature!)
        let pointFromPlot = plot.point(pressure: expected.pressure, temperature: expected.temperature)
        let recalculatedData = plot.pressureAndTemperature(atPoint: pointFromPlot)
        XCTAssertEqual(recalculatedData.pressure, expected.pressure, accuracy: 0.001)
        XCTAssertEqual(recalculatedData.temperature, expected.temperature, accuracy: 0.001)
        
        let data2 = sounding.data.filter({ $0.isPlottable }).last!
        let expected2 = (pressure: data2.pressure, temperature: data2.temperature!)
        let pointFromPlot2 = plot.point(pressure: expected2.pressure, temperature: expected2.temperature)
        let recalculatedData2 = plot.pressureAndTemperature(atPoint: pointFromPlot2)
        XCTAssertEqual(recalculatedData2.pressure, expected2.pressure, accuracy: 0.001)
        XCTAssertEqual(recalculatedData2.temperature, expected2.temperature, accuracy: 0.001)
    }
    
    func testCoordinateToPointAndBack() {
        let plot = SkewtPlot(sounding: sounding, size: CGSize(width: 100.0, height: 100.0))

        let data = sounding.data.filter({ $0.isPlottable })[15]
        let point = plot.point(pressure: data.pressure, temperature: data.temperature!)
        let dataFromPoint = plot.pressureAndTemperature(atPoint: point)
        let recalculatedPoint = plot.point(pressure: dataFromPoint.pressure, temperature: dataFromPoint.temperature)
        XCTAssertEqual(point.x, recalculatedPoint.x, accuracy: 0.5)
        XCTAssertEqual(point.y, recalculatedPoint.y, accuracy: 0.5)
    }
}
