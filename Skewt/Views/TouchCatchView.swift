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
        pincher.delegate = context.coordinator
        view.addGestureRecognizer(pincher)
        context.coordinator.pincher = pincher
        
        let tapper = UITapGestureRecognizer(target: context.coordinator, 
                                            action: #selector(Coordinator.tapperUpdated(_:)))
        tapper.delegate = context.coordinator
        view.addGestureRecognizer(tapper)
        context.coordinator.tapper = tapper
        
        let panner = UIPanGestureRecognizer(target: context.coordinator, 
                                            action: #selector(Coordinator.panUpdated(_:)))
        panner.delegate = context.coordinator
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
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TouchCatchView
        
        var pincher: UIPinchGestureRecognizer?
        var tapper: UITapGestureRecognizer?
        var panner: UIPanGestureRecognizer?
        
        var startingZoom: CGFloat = 1.0
        
        var panStart: CGPoint = .zero
        var panStartZoomAnchor: UnitPoint = .center
        
        init(_ parent: TouchCatchView) {
            self.parent = parent
        }
                
        private func updateAnnotationPoint(_ point: UnitPoint) {
            parent.annotationPoint = point
        }
        
        @objc func pinchUpdated(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:                
                guard let bounds = gesture.view?.bounds else {
                    return
                }
                
                let location = gesture.location(in: gesture.view)
                let distanceFromCenterOfVisible = UnitPoint(
                    x: (location.x - bounds.midX) / bounds.size.width,
                    y: (location.y - bounds.midY) / bounds.size.height
                )
                let existingOffset = UnitPoint(
                    x: parent.zoomAnchor.x - 0.5,
                    y: parent.zoomAnchor.y - 0.5
                )
                let visibleBounds = CGRect(
                    x: (1.0 - (1.0 / parent.zoom) + existingOffset.x) / 2.0,
                    y: (1.0 - (1.0 / parent.zoom) + existingOffset.y) / 2.0,
                    width: 1.0 / parent.zoom,
                    height: 1.0 / parent.zoom
                )
                
                startingZoom = parent.zoom
                parent.zoomAnchor = UnitPoint(
                    x: visibleBounds.midX + (distanceFromCenterOfVisible.x * visibleBounds.size.width),
                    y: visibleBounds.midY + (distanceFromCenterOfVisible.y * visibleBounds.size.height)
                )
                
                return
            case .changed:
                parent.zoom = max(parent.zoomRange.lowerBound, min(parent.zoomRange.upperBound, startingZoom * gesture.scale))
                return
            default:
                return
            }
        }
        
        @objc func panUpdated(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                panStartZoomAnchor = parent.zoomAnchor
                panStart = gesture.location(in: gesture.view)
                
                return
            case .changed:
                guard let bounds = gesture.view?.bounds else {
                    return
                }
                
                let location = gesture.location(in: gesture.view)
                
                if parent.zoom == 1.0 {
                    updateAnnotationPoint(UnitPoint(
                        x: location.x / bounds.size.width,
                        y: location.y / bounds.size.height
                    ))
                } else {
                    guard parent.zoom > 1.0 else {
                        parent.zoomAnchor = .center
                        return
                    }
                    
                    parent.zoomAnchor = UnitPoint(
                        x: panStartZoomAnchor.x - (location.x - panStart.x) / (bounds.size.width * parent.zoom),
                        y: panStartZoomAnchor.y - (location.y - panStart.y) / (bounds.size.height * parent.zoom)
                    )
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


