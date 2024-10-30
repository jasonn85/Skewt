//
//  SkewTPlotTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 3/3/23.
//

import XCTest
@testable import Skewt

extension CGPathElement {
    var numberOfPoints: Int {
        switch self.type {
        case .moveToPoint, .addLineToPoint:
            return 1
        case .addQuadCurveToPoint:
            return 2
        case .addCurveToPoint:
            return 3
        case .closeSubpath:
            return 0
        default:
            return 0
        }
    }
}

extension CGPath {
    /// Tests that all linear pieces of the path draw a positive slope.
    /// Ignores curved elements.
    var isPositiveSlope: Bool {
        let points = componentEndPoints
        var lastX = -CGFloat.infinity
        
        for point in points.sorted(by: { $0.y > $1.y }) {
            if point.x <= lastX {
                return false
            }
            
            lastX = point.x
        }
        
        return true
    }
    
    /// The last point in each path element
    var componentEndPoints: [CGPoint] {
        var points: [CGPoint] = []
                
        applyWithBlock {
            let element = $0.pointee
            let pointCount = element.numberOfPoints
            
            guard pointCount > 0 else {
                return
            }
            
            let lastPoint = Array(UnsafeBufferPointer(start: element.points, count: pointCount)).last!
            points.append(lastPoint)
        }
        
        return points
    }
    
    var bottomPoint: CGPoint? {
        return componentEndPoints.sorted(by: { $0.y < $1.y }).last
    }
    
    func intersectsRect(_ rect: CGRect) -> Bool {
        return componentEndPoints.first(where: { rect.contains($0) }) != nil
    }
    
    func isContainedWithinRect(_ rect: CGRect) -> Bool {
        return componentEndPoints.first(where: { !rect.contains($0) }) == nil
    }
}

final class SkewTPlotTests: XCTestCase {
    var sounding: Sounding!
    
    override func setUpWithError() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "ord-gfs-1", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        sounding = try RucSounding(fromText: s)
    }
    
    func testNilSoundingMakesNilPaths() {
        let plot = SkewtPlot(sounding: nil)
        XCTAssertNil(plot.temperaturePath, "No data generates a nil temperature path")
        XCTAssertNil(plot.dewPointPath, "No data generates a nil dew point path")
    }

    func testPlottablePointsMakePath() throws {
        let plot = SkewtPlot(sounding: sounding)
        
        XCTAssertFalse(plot.temperaturePath!.isEmpty, "Data generates a path for temperature")
        XCTAssertFalse(plot.dewPointPath!.isEmpty, "Data generates a path for dew point")
        XCTAssertTrue(plot.temperaturePath!.boundingBox.size.width > 0)
        XCTAssertTrue(plot.temperaturePath!.boundingBox.size.height > 0)
        XCTAssertTrue(plot.dewPointPath!.boundingBox.size.width > 0)
        XCTAssertTrue(plot.dewPointPath!.boundingBox.size.height > 0)
    }
    
    func testConstantTemperatureSlopesRight() throws {
        let constantTempSounding = try RucSounding(fromText: """
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
        let plot = SkewtPlot(sounding: constantTempSounding)
        
        XCTAssertTrue(plot.temperaturePath!.isPositiveSlope)
    }
    
    func testNonsenseTemperaturesStayInBounds() throws {
        let bundle = Bundle(for: type(of: self))
        let fileUrl = bundle.url(forResource: "out-of-bounds-op40", withExtension: "txt")!
        let d = try Data(contentsOf: fileUrl)
        let s = String(data: d, encoding: .utf8)!
        let sounding = try RucSounding(fromText: s)
        let plot = SkewtPlot(sounding: sounding)
        
        // Allow off-screen left, right, and up by a factor of 1. Down should always be in bounds.
        let bounds = CGRect(x: -1.0, y: -1.0, width: 3.0, height: 2.0)
        
        XCTAssertTrue(plot.temperaturePath!.isContainedWithinRect(bounds), "Temperature path stays within reasonable bounds")
        XCTAssertTrue(plot.dewPointPath!.isContainedWithinRect(bounds), "Dew point path stays within reasonable bounds")
    }
    
    func testIsobarNonLinearScale() {
        let height = 1.0
        let plot = SkewtPlot(sounding: sounding)
        let isobarPaths = plot.isobarPaths
        let sortedIsobars = plot.isobarPaths.keys.sorted().reversed().map { isobarPaths[$0]! }
        
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
        let squarePlot = SkewtPlot(sounding: sounding)
        
        let bottomLeft = CGPoint(x: 0.0, y: 1.0)
        let middleBottom = CGPoint(x: 0.5, y: 1.0)
        let middleLeft = CGPoint(x: 0.0, y: 0.5)
        let middleRight = CGPoint(x: 1.0, y: 0.5)
        let middleTop = CGPoint(x: 0.5, y: 0.0)
        let topRight = CGPoint(x: 1.0, y: 0.0)
        let (_, bottomLeftTemp) = squarePlot.pressureAndTemperature(atPoint: bottomLeft)
        let (_, middleTemp) = squarePlot.pressureAndTemperature(atPoint: middleBottom)
        let (_, halfOffLeftTemp) = squarePlot.pressureAndTemperature(atPoint: CGPoint(x: -0.5, y: 1.0))
        let fullLine = squarePlot.isotherm(forTemperature: bottomLeftTemp)
        let halfAcrossLine = squarePlot.isotherm(forTemperature: middleTemp)
        let halfOffLeftLine = squarePlot.isotherm(forTemperature: halfOffLeftTemp)
        
        XCTAssertEqual(fullLine.0, bottomLeft)
        XCTAssertEqual(fullLine.1, topRight)
        XCTAssertEqual(halfAcrossLine.0, middleBottom)
        XCTAssertEqual(halfAcrossLine.1, middleRight)
        XCTAssertEqual(halfOffLeftLine.0, middleLeft)
        XCTAssertEqual(halfOffLeftLine.1, middleTop)
        
        let unskewedSquarePlot = SkewtPlot(sounding: sounding, surfaceTemperatureRange: squarePlot.surfaceTemperatureRange, pressureRange: squarePlot.pressureRange, isothermSpacing: squarePlot.isothermSpacing, adiabatSpacing: squarePlot.adiabatSpacing, isobarSpacing: squarePlot.isothermSpacing, isohumes: squarePlot.isohumes, altitudeIsobars: squarePlot.altitudeIsobars, skew: 0.0)
        let vertical = unskewedSquarePlot.isotherm(forTemperature: middleTemp)
        XCTAssertEqual(vertical.0, middleBottom)
        XCTAssertEqual(vertical.1, middleTop)
        
        let lessSkewedSquarePlot = SkewtPlot(sounding: sounding, surfaceTemperatureRange: squarePlot.surfaceTemperatureRange, pressureRange: squarePlot.pressureRange, isothermSpacing: squarePlot.isothermSpacing, adiabatSpacing: squarePlot.adiabatSpacing, isobarSpacing: squarePlot.isothermSpacing, isohumes: squarePlot.isohumes, altitudeIsobars: squarePlot.altitudeIsobars, skew: 0.5)
        let steepFromBottomLeft = lessSkewedSquarePlot.isotherm(forTemperature: bottomLeftTemp)
        let steepFromBottomMiddle = lessSkewedSquarePlot.isotherm(forTemperature: middleTemp)
        XCTAssertEqual(steepFromBottomLeft.0, bottomLeft)
        XCTAssertEqual(steepFromBottomLeft.1, middleTop)
        XCTAssertEqual(steepFromBottomMiddle.0, middleBottom)
        XCTAssertEqual(steepFromBottomMiddle.1, topRight)
        
        let moreSkewedSquarePlot = SkewtPlot(sounding: sounding, surfaceTemperatureRange: squarePlot.surfaceTemperatureRange, pressureRange: squarePlot.pressureRange, isothermSpacing: squarePlot.isothermSpacing, adiabatSpacing: squarePlot.adiabatSpacing, isobarSpacing: squarePlot.isothermSpacing, isohumes: squarePlot.isohumes, altitudeIsobars: squarePlot.altitudeIsobars, skew: 2.0)
        let shallowFromBottomLeft = moreSkewedSquarePlot.isotherm(forTemperature: bottomLeftTemp)
        XCTAssertEqual(shallowFromBottomLeft.0, bottomLeft)
        XCTAssertEqual(shallowFromBottomLeft.1, middleRight)
    }
    
    func testIsothermSkew() {
        let plot = SkewtPlot(sounding: sounding)
        
        XCTAssertTrue(plot.isothermPaths.count > 0)
        
        plot.isothermPaths.forEach {
            XCTAssertTrue($0.1.isPositiveSlope, "Slope of isotherm should be positive: \(String(describing: $0))")
        }
    }
    
    /// A roughly square plot should have twice as many isotherms as fill the X axis
    func testIsothermCount() {
        let plot = SkewtPlot(sounding: sounding)
        let singleAxisCount = Int((plot.surfaceTemperatureRange.upperBound
                                   - plot.surfaceTemperatureRange.lowerBound)
                                  / plot.isothermSpacing)
        let expectedCount = (singleAxisCount * 2 - 2)...(singleAxisCount * 2 + 2)
        
        XCTAssertTrue(expectedCount.contains(plot.isothermPaths.count),
                      "Expecting \(String(describing: expectedCount)) isotherms, found \(plot.isobarPaths.count)")
    }
    
    func testAdiabatCount() {
        // It's not yet defined if/how many dry adiabats should be drawn from off screen right, so just
        // ensure that we have at least enough to cover the bottom.
        let plot = SkewtPlot(sounding: sounding)
        let singleAxisCount = Int((plot.surfaceTemperatureRange.upperBound
                                   - plot.surfaceTemperatureRange.lowerBound)
                                  / plot.adiabatSpacing) - 2
        
        let bounds = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let inBoundsDryAdiabatPaths = plot.dryAdiabatPaths.filter { $0.value.intersectsRect(bounds) }
        let inBoundsMoistAdiabatPaths = plot.moistAdiabatPaths.filter { $0.value.intersectsRect(bounds) }
        
        let minimumDryAdiabats = Int(Double(singleAxisCount) * 1.5)
                        
        XCTAssertTrue(inBoundsDryAdiabatPaths.count >= minimumDryAdiabats,
                      "There should be at least ~\(minimumDryAdiabats) dry adiabats")
        XCTAssertTrue(inBoundsMoistAdiabatPaths.count >= singleAxisCount,
                      "There should be at least \(singleAxisCount) moist adiabats")
    }
    
    func testDataToCoordinateAndBack() {
        let plot = SkewtPlot(sounding: sounding)

        let data = sounding.data.dataPoints.filter({ $0.temperature != nil }).first!
        let expected = (pressure: data.pressure, temperature: data.temperature!)
        let pointFromPlot = plot.point(pressure: expected.pressure, temperature: expected.temperature)
        let recalculatedData = plot.pressureAndTemperature(atPoint: pointFromPlot)
        XCTAssertEqual(recalculatedData.pressure, expected.pressure, accuracy: 0.001)
        XCTAssertEqual(recalculatedData.temperature, expected.temperature, accuracy: 0.001)
        
        let data2 = sounding.data.dataPoints.filter({ $0.temperature != nil }).last!
        let expected2 = (pressure: data2.pressure, temperature: data2.temperature!)
        let pointFromPlot2 = plot.point(pressure: expected2.pressure, temperature: expected2.temperature)
        let recalculatedData2 = plot.pressureAndTemperature(atPoint: pointFromPlot2)
        XCTAssertEqual(recalculatedData2.pressure, expected2.pressure, accuracy: 0.001)
        XCTAssertEqual(recalculatedData2.temperature, expected2.temperature, accuracy: 0.001)
    }
    
    func testCoordinateToPointAndBack() {
        let plot = SkewtPlot(sounding: sounding)

        let data = sounding.data.dataPoints.filter({ $0.temperature != nil })[15]
        let point = plot.point(pressure: data.pressure, temperature: data.temperature!)
        let dataFromPoint = plot.pressureAndTemperature(atPoint: point)
        let recalculatedPoint = plot.point(pressure: dataFromPoint.pressure, temperature: dataFromPoint.temperature)
        XCTAssertEqual(point.x, recalculatedPoint.x, accuracy: 0.5)
        XCTAssertEqual(point.y, recalculatedPoint.y, accuracy: 0.5)
    }
    
    func testDefaultAltitudeRangeVsPressureRange() {
        let plot = SkewtPlot(sounding: sounding)
        let pressureTolerance = 1.0
        let altitudeTolerance = 50.0
        
        XCTAssertEqual(Pressure.standardPressure(atAltitude: plot.altitudeRange.lowerBound),
                       plot.pressureRange.upperBound,
                       accuracy: pressureTolerance)
        XCTAssertEqual(Pressure.standardPressure(atAltitude: plot.altitudeRange.upperBound),
                       plot.pressureRange.lowerBound,
                       accuracy: pressureTolerance)
        XCTAssertEqual(Altitude.standardAltitude(forPressure: plot.pressureRange.lowerBound),
                       plot.altitudeRange.upperBound,
                       accuracy: altitudeTolerance)
        XCTAssertEqual(Altitude.standardAltitude(forPressure: plot.pressureRange.upperBound),
                       plot.altitudeRange.lowerBound,
                       accuracy: altitudeTolerance)
    }
    
    func testChangingAltitudeRange() {
        let pressureTolerance = 1.0
        let altitudeTolerance = 50.0
        
        var plot = SkewtPlot(sounding: sounding)
        let altitudeRange = 0.0...10_000.0
        plot.altitudeRange = altitudeRange
        
        XCTAssertEqual(plot.altitudeRange.lowerBound,
                       altitudeRange.lowerBound,
                       accuracy: altitudeTolerance)
        XCTAssertEqual(plot.altitudeRange.upperBound,
                       altitudeRange.upperBound,
                       accuracy: altitudeTolerance)
        XCTAssertEqual(plot.pressureRange.upperBound,
                       Pressure.standardPressure(atAltitude: altitudeRange.lowerBound),
                       accuracy: pressureTolerance)
        XCTAssertEqual(plot.pressureRange.lowerBound,
                       Pressure.standardPressure(atAltitude: altitudeRange.upperBound),
                       accuracy: pressureTolerance)
    }
    
    func testLineConstraint() {
        let normalBounds = CGRect(origin: .zero, size: CGSize(width: 1.0, height: 1.0))
        
        let bottomLeft = CGPoint(x: 0.0, y: 1.0)
        let bottomRight = CGPoint(x: 1.0, y: 1.0)
        let middleBottomish = CGPoint(x: 0.5, y: 0.88)
        let middleLeftish = CGPoint(x: 0.15, y: 0.5)
        let middleRightish = CGPoint(x: 0.9, y: 0.5)
        let middleTopish = CGPoint(x: 0.5, y: 0.1)
        let topLeft = CGPoint(x: 0.0, y: 0.0)
        let topRight = CGPoint(x: 1.0, y: 0.0)
        let insidePoints = [bottomLeft, bottomRight, middleBottomish, middleLeftish,
                            middleRightish, middleTopish, topLeft, topRight]
                
        insidePoints.forEach { a in
            insidePoints.forEach { b in
                let constrained = normalBounds.constrainLine((a, b))!
                
                XCTAssertEqual(constrained.0, a, "Line already within rect, when constrained, is the same")
                XCTAssertEqual(constrained.1, b, "Line already within rect, when constrained, is the same")
            }
        }
        
        let diagonalAcross = (CGPoint(x: -1.0, y: 2.0), CGPoint(x: 2.0, y: -1.0))
        let diagonalConstrained = normalBounds.constrainLine(diagonalAcross)!
        XCTAssertEqual(diagonalConstrained.0, bottomLeft)
        XCTAssertEqual(diagonalConstrained.1, topRight)
        
        stride(from: 0.0, through: 1.0, by: 0.1).forEach {
            let horizontal = (CGPoint(x: $0, y: -1.0), CGPoint(x: $0, y: 2.0))
            let constrainedHorizontal = normalBounds.constrainLine(horizontal)!
            
            XCTAssertEqual(constrainedHorizontal.0.x, $0)
            XCTAssertEqual(constrainedHorizontal.0.y, 0.0)
            XCTAssertEqual(constrainedHorizontal.1.x, $0)
            XCTAssertEqual(constrainedHorizontal.1.y, 1.0)
            
            let vertical = (CGPoint(x: -1.0, y: $0), CGPoint(x: 2.0, y: $0))
            let constraintedVertical = normalBounds.constrainLine(vertical)!
            
            XCTAssertEqual(constraintedVertical.0.x, 0.0)
            XCTAssertEqual(constraintedVertical.0.y, $0)
            XCTAssertEqual(constraintedVertical.1.x, 1.0)
            XCTAssertEqual(constraintedVertical.1.y, $0)
        }
    }
}
