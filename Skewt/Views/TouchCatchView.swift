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
    
    var bounceBackAnimation: Animation?
    
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
        var panStartSquare: ZoomedSquare? = nil
        
        init(_ parent: TouchCatchView) {
            self.parent = parent
        }
                
        private func updateAnnotationPoint(_ point: UnitPoint) {
            guard let visibleSquare = try? ZoomedSquare(zoom: parent.zoom, anchor: parent.zoomAnchor) else {
                return
            }
            
            parent.annotationPoint = visibleSquare.actualPointForVisiblePoint(point)
        }
        
        @objc func pinchUpdated(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:                
                guard let bounds = gesture.view?.bounds,
                        let currentRect = try? ZoomedSquare(zoom: parent.zoom, anchor: parent.zoomAnchor) else {
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
                panStartSquare = try? ZoomedSquare(zoom: parent.zoom, anchor: parent.zoomAnchor)
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
                
                if parent.zoom == 1.0 {
                    updateAnnotationPoint(visibleNormalizedLocation)
                } else {
                    let distance = (x: panStart.x - location.x, y: panStart.y - location.y)
                    let normalizedDistance = (x: distance.x / bounds.size.width, y: distance.y / bounds.size.height)
                    
                    let transaction = Transaction(animation: bounceBackToContent ? parent.bounceBackAnimation : nil)
                    
                    withTransaction(transaction) {
                        parent.zoomAnchor = panStartSquare.pannedBy(
                            x: normalizedDistance.x,
                            y: normalizedDistance.y,
                            constrainToContent: bounceBackToContent
                        ).anchor
                    }
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
                let visibleNormalizedLocation = UnitPoint(x: location.x / bounds.size.width,
                                                          y: location.y / bounds.size.height)
                updateAnnotationPoint(visibleNormalizedLocation)
                
                return
            
            default:
                return
            }
        }
    }
}
