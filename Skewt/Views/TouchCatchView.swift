//
//  TouchCatchView.swift
//  Skewt
//
//  Created by Jason Neel on 1/30/24.
//

import SwiftUI

struct TouchCatchView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    @Binding var annotationPoint: CGPoint?
    @Binding var zoom: CGFloat
    @Binding var zoomOffset: CGPoint
    
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
        
        let panner = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.panUpdated(_:)))
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
        var pinchCenter: CGPoint = .zero
        
        var startingOffset: CGPoint = .zero
        var longPressStart: CGPoint = .zero
        
        init(_ parent: TouchCatchView) {
            self.parent = parent
        }
        
        private func updateOffset(dx: CGFloat, dy: CGFloat) {
            guard parent.zoom > 1.0 else {
                parent.zoomOffset = .zero
                return
            }
            
            // TODO: Constrain to bounds
            parent.zoomOffset = CGPoint(
                x: startingOffset.x - dx,
                y: startingOffset.y - dy
            )
        }
        
        private func updateAnnotationPoint(_ point: CGPoint) {
            parent.annotationPoint = point
        }
        
        @objc func pinchUpdated(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                startingZoom = parent.zoom
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
                startingOffset = parent.zoomOffset
                longPressStart = gesture.location(in: gesture.view)
                
                return
            case .changed:
                guard let bounds = gesture.view?.bounds else {
                    return
                }
                
                let location = gesture.location(in: gesture.view)
                
                if parent.zoom == 1.0 {
                    updateAnnotationPoint(CGPoint(
                        x: location.x / bounds.size.width,
                        y: location.y / bounds.size.height
                    ))
                } else {
                    updateOffset(
                        dx: (location.x - longPressStart.x) / bounds.size.width,
                        dy: (location.y - longPressStart.y) / bounds.size.height
                    )
                }
            
                return
            default:
                return
            }
        }
        
        @objc func tapperUpdated(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .changed:
                guard let bounds = gesture.view?.bounds else {
                    return
                }
                
                let location = gesture.location(in: gesture.view)
                
                updateAnnotationPoint(CGPoint(
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


