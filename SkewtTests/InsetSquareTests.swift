//
//  InsetSquareTests.swift
//  SkewtTests
//
//  Created by Jason Neel on 1/31/24.
//

import XCTest
import SwiftUI
@testable import Skewt

final class InsetSquareTests: XCTestCase {
    func testDisallowBadZooms() {
        do {
            let _ = try InsetSquare(zoom: 0.0, anchor: .center)
            XCTFail("0 zoom is disallowed")
        } catch {
        }
        
        do {
            let _ = try InsetSquare(zoom: -1.0, anchor: .center)
            XCTFail("negative zoom is disallowed")
        } catch {
        }
    }
    
    func testUnzoomed() {
        let square = try! InsetSquare(zoom: 1.0, anchor: .center)
        
        let unitRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        
        XCTAssertEqual(square.visibleRect, unitRect)
        XCTAssertEqual(square.actualPointForVisiblePoint(.center), .center)
    }
    
    func testZoomingDoesNotChangeCenter() {
        for zoom in [1.0, 2.0, 5.0] {
            let square = try! InsetSquare(zoom: zoom, anchor: .center)
            XCTAssertEqual(square.visiblePointForActualPoint(.center), .center,
                           "Actual center at zoom \(zoom) is the center of the visible content")
            XCTAssertEqual(square.actualPointForVisiblePoint(.center), .center,
                           "Visible center at zoom \(zoom) is the center of the actual content")
        }
    }
    
    func testPanIdentity() {
        let square = try! InsetSquare(zoom: 2.0, anchor: .center)

        XCTAssertEqual(square.pannedBy(x: 0.0, y: 0.0, constrainToContent: false).visibleRect, square.visibleRect)
        XCTAssertEqual(square.pannedBy(x: 0.0, y: 0.0, constrainToContent: true).visibleRect, square.visibleRect)
    }
    
    func testUnzoomedVisibleRect() {
        let unzoomed = try! InsetSquare(zoom: 1.0, anchor: .center)
        let anchors: [UnitPoint] = [.top, .bottom, .leading, .trailing, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
        
        anchors.forEach {
            XCTAssertEqual(try! InsetSquare(zoom: 1.0, anchor: $0).visibleRect, unzoomed.visibleRect)
        }
    }
    
    func testTwoXPanConstraining() {
        let square = try! InsetSquare(zoom: 2.0, anchor: .center)

        XCTAssertEqual(square.pannedBy(x: -1.0, y: -1.0, constrainToContent: true).anchor, UnitPoint(x: 0.0, y: 0.0))
        XCTAssertEqual(square.pannedBy(x: -2.0, y: -2.0, constrainToContent: true).anchor, UnitPoint(x: 0.0, y: 0.0))
        XCTAssertEqual(square.pannedBy(x: 1.0, y: 1.0, constrainToContent: true).anchor, UnitPoint(x: 1.0, y: 1.0))
        XCTAssertEqual(square.pannedBy(x: 2.0, y: 2.0, constrainToContent: true).anchor, UnitPoint(x: 1.0, y: 1.0))
    }
    
    func testFourXPanConstrainint() {
        let square = try! InsetSquare(zoom: 4.0, anchor: .center)

        XCTAssertEqual(square.pannedBy(x: -2.0, y: -2.0, constrainToContent: true).anchor, UnitPoint(x: 0.0, y: 0.0))
        XCTAssertEqual(square.pannedBy(x: -10.0, y: -10.0, constrainToContent: true).anchor, UnitPoint(x: 0.0, y: 0.0))
        XCTAssertEqual(square.pannedBy(x: 2.0, y: 2.0, constrainToContent: true).anchor, UnitPoint(x: 1.0, y:  1.0))
        XCTAssertEqual(square.pannedBy(x: 10.0, y: 10.0, constrainToContent: true).anchor, UnitPoint(x: 1.0, y: 1.0))
    }
    
    func testPanning() {
        let square = try! InsetSquare(zoom: 3.0, anchor: .center)
        
        XCTAssertEqual(square.visibleRect.minX, 0.33, accuracy: 0.05)
        XCTAssertEqual(square.visibleRect.minY, 0.33, accuracy: 0.05)
        XCTAssertEqual(square.visibleRect.maxX, 0.66, accuracy: 0.05)
        XCTAssertEqual(square.visibleRect.maxY, 0.66, accuracy: 0.05)

        XCTAssertEqual(square.pannedBy(x: -1.0, y: 0.0).visibleRect.minX, 0.0, accuracy: 0.05)
        XCTAssertEqual(square.pannedBy(x: 0.0, y: -1.0).visibleRect.minY, 0.0, accuracy: 0.05)
        XCTAssertEqual(square.pannedBy(x: 1.0, y: 0.0).visibleRect.maxX, 1.0, accuracy: 0.05)
        XCTAssertEqual(square.pannedBy(x: 0.0, y: 1.0).visibleRect.maxY, 1.0, accuracy: 0.05)
        
        XCTAssert(square.pannedBy(x: -2.0, y: 0.0, constrainToContent: false).visibleRect.minX < 0.0)
        XCTAssertEqual(square.pannedBy(x: -2.0, y: 0.0, constrainToContent: true).visibleRect.minX, 0.0, accuracy: 0.05)
        XCTAssert(square.pannedBy(x: 2.0, y: 0.0, constrainToContent: false).visibleRect.maxX > 1.0)
        XCTAssertEqual(square.pannedBy(x: 2.0, y: 0.0, constrainToContent: true).visibleRect.maxX, 1.0, accuracy: 0.05)
        XCTAssert(square.pannedBy(x: 0.0, y: -2.0, constrainToContent: false).visibleRect.minY < 0.0)
        XCTAssertEqual(square.pannedBy(x: 0.0, y: -2.0, constrainToContent: true).visibleRect.minY, 0.0, accuracy: 0.05)
        XCTAssert(square.pannedBy(x: 0.0, y: 2.0, constrainToContent: false).visibleRect.maxY > 1.0)
        XCTAssertEqual(square.pannedBy(x: 0.0, y: 2.0, constrainToContent: true).visibleRect.maxY, 1.0, accuracy: 0.05)
    }
    
    func testUnzoomedPointConversions() {
        let square = try! InsetSquare(zoom: 1.0, anchor: .center)

        let points: [UnitPoint] = [
            .center, .top, .bottom, .leading, .trailing, .topLeading,
            .topTrailing, .bottomLeading, .bottomTrailing
        ]
        let tolerance = 0.001
        
        for p in points {
            XCTAssertEqual(square.visiblePointForActualPoint(p).x, p.x, accuracy: tolerance)
            XCTAssertEqual(square.visiblePointForActualPoint(p).y, p.y, accuracy: tolerance)
            XCTAssertEqual(square.actualPointForVisiblePoint(p).x, p.x, accuracy: tolerance)
            XCTAssertEqual(square.actualPointForVisiblePoint(p).y, p.y, accuracy: tolerance)
        }
    }
    
    func testPointConversionCommutativity() {
        let zooms: [CGFloat] = [1.0, 2.0, 3.0, 5.0]
        let points: [UnitPoint] = [
            .center, .top, .bottom, .leading, .trailing, .topLeading,
            .topTrailing, .bottomLeading, .bottomTrailing
        ]
        let tolerance = 0.001
        
        for zoom in zooms {
            for anchor in points {
                let square = try! InsetSquare(zoom: zoom, anchor: anchor)
                
                for p in points {
                    XCTAssertEqual(square.visiblePointForActualPoint(square.actualPointForVisiblePoint(p)).x, p.x, accuracy: tolerance)
                    XCTAssertEqual(square.visiblePointForActualPoint(square.actualPointForVisiblePoint(p)).y, p.y, accuracy: tolerance)
                    XCTAssertEqual(square.actualPointForVisiblePoint(square.visiblePointForActualPoint(p)).x, p.x, accuracy: tolerance)
                    XCTAssertEqual(square.actualPointForVisiblePoint(square.visiblePointForActualPoint(p)).y, p.y, accuracy: tolerance)
                }
            }
        }
    }
    
    func testPointConversions() {
        let topLeftDoubled = try! InsetSquare(zoom: 2.0, anchor: .topLeading)
        XCTAssertEqual(topLeftDoubled.visiblePointForActualPoint(.center), .bottomTrailing)
        XCTAssertEqual(topLeftDoubled.actualPointForVisiblePoint(.bottomTrailing), .center)
        
        let bottomRightDoubled = try! InsetSquare(zoom: 2.0, anchor: .bottomTrailing)
        XCTAssertEqual(bottomRightDoubled.visiblePointForActualPoint(.center), .topLeading)
        XCTAssertEqual(bottomRightDoubled.actualPointForVisiblePoint(.topLeading), .center)
    }
}
