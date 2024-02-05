//
//  TouchCatchView.swift
//  Skewt
//
//  Created by Jason Neel on 1/30/24.
//

import SwiftUI

/// A UIKit view and coordinator to handle zoom/pan/touch gestures better than is yet possible in SwiftUI
struct TouchCatchView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    @Binding var annotationPoint: UnitPoint?
    @Binding var zoom: CGFloat
    @Binding var zoomAnchor: UnitPoint
    
    var zoomRange: ClosedRange<CGFloat> = 1.0...3.0

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        let pincher = UIPinchGestureRecognizer(target: context.coordinator, 
                                               action: #selector(Coordinator.pinchUpdated(_:)))
        view.addGestureRecognizer(pincher)
        context.coordinator.pincher = pincher
        
        let tapper = UITapGestureRecognizer(target: context.coordinator, 
                                            action: #selector(Coordinator.tapperUpdated(_:)))
        view.addGestureRecognizer(tapper)
        context.coordinator.tapper = tapper
        
        let panner = UIPanGestureRecognizer(target: context.coordinator, 
                                            action: #selector(Coordinator.panUpdated(_:)))
        view.addGestureRecognizer(panner)
        context.coordinator.panner = panner
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // This page intentionally left blank
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension TouchCatchView {
    class Coordinator {
        var parent: TouchCatchView
        
        var pincher: UIPinchGestureRecognizer?
        var tapper: UITapGestureRecognizer?
        var panner: UIPanGestureRecognizer?
        
        var startingZoom: CGFloat = 1.0
        
        var panStart: CGPoint = .zero
        var panStartSquare: InsetSquare? = nil
        
        init(_ parent: TouchCatchView) {
            self.parent = parent
        }
                
        private func updateAnnotationPoint(_ point: UnitPoint) {
            parent.annotationPoint = point
        }
        
        @objc func pinchUpdated(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:                
                guard let bounds = gesture.view?.bounds,
                        let currentRect = try? InsetSquare(zoom: parent.zoom, anchor: parent.zoomAnchor) else {
                    return
                }
                
                let location = gesture.location(in: gesture.view)
                let normalizedLocation = UnitPoint(x: location.x / bounds.size.width,
                                                   y: location.y / bounds.size.height)
                
                startingZoom = parent.zoom
                parent.zoomAnchor = currentRect.actualPointForVisiblePoint(normalizedLocation)
                
                return
            case .changed:
                parent.zoom = max(parent.zoomRange.lowerBound, min(parent.zoomRange.upperBound, startingZoom * gesture.scale))
                return
            default:
                return
            }
        }
        
        @objc func panUpdated(_ gesture: UIPanGestureRecognizer) {
            var bounceBackToContent = false
            
            switch gesture.state {
            case .began:
                panStartSquare = try? InsetSquare(zoom: parent.zoom, anchor: parent.zoomAnchor)
                panStart = gesture.location(in: gesture.view)
                
                return
            case .ended:
                bounceBackToContent = true
                fallthrough
            case .changed:
                guard let bounds = gesture.view?.bounds, let panStartSquare = panStartSquare else {
                    return
                }
                
                let location = gesture.location(in: gesture.view)
                let visibleNormalizedLocation = UnitPoint(x: location.x / bounds.size.width,
                                                          y: location.y / bounds.size.height)
                let normalizedLocation = panStartSquare.actualPointForVisiblePoint(visibleNormalizedLocation)
                
                if parent.zoom == 1.0 {
                    updateAnnotationPoint(normalizedLocation)
                } else {
                    let distance = (x: panStart.x - location.x, y: panStart.y - location.y)
                    let normalizedDistance = (x: distance.x / bounds.size.width, y: distance.y / bounds.size.height)
                    
                    parent.zoomAnchor = panStartSquare.pannedBy(
                        x: normalizedDistance.x,
                        y: normalizedDistance.y,
                        constrainToContent: bounceBackToContent
                    ).anchor
                }
            
                return
            default:
                return
            }
        }
        
        @objc func tapperUpdated(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .ended:
                guard let bounds = gesture.view?.bounds else {
                    return
                }
                
                let location = gesture.location(in: gesture.view)
                
                updateAnnotationPoint(UnitPoint(
                    x: location.x / bounds.size.width,
                    y: location.y / bounds.size.height
                ))
                
                return
            
            default:
                return
            }
        }
    }
}

enum InsetRectError: Error {
    case invalidZoom
}

/// A struct to represent a zoomed in area of a square UnitRect with an arbitrary anchor point
struct InsetSquare {
    let zoom: CGFloat
    let anchor: UnitPoint
    
    init(zoom: CGFloat, anchor: UnitPoint) throws {
        if zoom <= 0.0 {
            throw InsetRectError.invalidZoom
        }
        
        self.zoom = zoom
        self.anchor = anchor
    }
    
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
        let visibleCenter = UnitPoint(x: visibleRect.midX, y: visibleRect.midY)
        let distanceFromVisibleCenter = (x: (p.x - visibleCenter.x) / zoom, y: (p.y - visibleCenter.y) / zoom)
        
        return UnitPoint(x: visibleCenter.x + distanceFromVisibleCenter.x, y: visibleCenter.y + distanceFromVisibleCenter.y)
    }
    
    func pannedBy(x: CGFloat, y: CGFloat, constrainToContent: Bool = false) -> InsetSquare {
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
        
        return try! InsetSquare(zoom: zoom, anchor: newAnchor)
    }
}


