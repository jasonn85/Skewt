//
//  ZoomedSquare.swift
//  Skewt
//
//  Created by Jason Neel on 2/7/24.
//

import SwiftUI

enum InsetRectError: Error {
    case invalidZoom
}

/// A zoomed in area of a unit square with an arbitrary anchor point
struct ZoomedSquare {
    let zoom: CGFloat
    let anchor: UnitPoint
    
    init(zoom: CGFloat, anchor: UnitPoint) throws {
        if zoom <= 0.0 {
            throw InsetRectError.invalidZoom
        }
        
        self.zoom = zoom
        self.anchor = anchor
    }
    
    /// A rect of coordinates in the 0-1 content space that shows the visible area
    var visibleRect: CGRect {
        CGRect(
            x: anchor.x - (anchor.x / zoom),
            y: anchor.y - (anchor.y / zoom),
            width: 1.0 / zoom,
            height: 1.0 / zoom
        )
    }
    
    /// Takes a UnitPoint that represents a position in the currently-zoomed view and returns its unzoomed coordinate.
    func actualPointForVisiblePoint(_ p: UnitPoint) -> UnitPoint {
        UnitPoint(
            x: p.x / zoom - anchor.x / zoom + anchor.x,
            y: p.y / zoom - anchor.y / zoom + anchor.y
        )
    }
    
    /// Takes a UnitPoint that represents a visible point and returns that point in the unzoomed 0-1 coordinate space.
    func visiblePointForActualPoint(_ p: UnitPoint) -> UnitPoint {
        UnitPoint(
            x: p.x * zoom - anchor.x * zoom + anchor.x,
            y: p.y * zoom - anchor.y * zoom + anchor.y
        )
    }
    
    /// Pan the visible square by the specified X/Y values, optionally constraining the visible area to the content bounds
    func pannedBy(x: CGFloat, y: CGFloat, constrainToContent: Bool = false) -> ZoomedSquare {
        guard zoom != 1.0 else {
            return self
        }
        
        let scaledX = x / (zoom - 1.0)
        let scaledY = y / (zoom - 1.0)
        
        var newAnchor = UnitPoint(x: anchor.x + scaledX, y: anchor.y + scaledY)
        let anchorRange = 0.0...1.0
        
        if constrainToContent {
            if newAnchor.x < anchorRange.lowerBound {
                newAnchor.x = anchorRange.lowerBound
            } else if newAnchor.x > anchorRange.upperBound {
                newAnchor.x = anchorRange.upperBound
            }
            
            if newAnchor.y < anchorRange.lowerBound {
                newAnchor.y = anchorRange.lowerBound
            } else if newAnchor.y > anchorRange.upperBound {
                newAnchor.y = anchorRange.upperBound
            }
        }
        
        return try! ZoomedSquare(zoom: zoom, anchor: newAnchor)
    }
}
