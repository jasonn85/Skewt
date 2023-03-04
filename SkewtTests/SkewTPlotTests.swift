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
        
        XCTAssertTrue(expectedCount.contains(plot.isobarPaths.count))
    }
}
