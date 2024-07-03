//
//  AnimatedWindView.swift
//  Skewt
//
//  Created by Jason Neel on 11/23/23.
//

import SwiftUI

fileprivate let windSpanKey = "windVerticalSpan"
fileprivate let windVelocityKey = "windVelocity"

fileprivate typealias WindSpan = ClosedRange<CGFloat>
fileprivate typealias WindEmitter = CAEmitterLayer

fileprivate extension WindEmitter {
    var windSpan: WindSpan? {
        get { value(forKey: windSpanKey) as? WindSpan }
        set { setValue(newValue, forKey: windSpanKey) }
    }
    
    var windVelocity: Double? {
        get { value(forKey: windVelocityKey) as? Double }
        set { setValue(newValue, forKey: windVelocityKey) }
    }
}

fileprivate extension UIView {
    var windEmitters: [WindEmitter] {
        (layer.sublayers ?? []).filter({ ($0 as? WindEmitter)?.windSpan != nil }) as! [WindEmitter]
    }
}

struct AnimatedWindView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    let frame: CGRect
    
    /// Dictionary of 1d wind data keyed by [0...1] height
    let winds: [Double: Double]?
    let minimumWindToAnimate = 10.0
    
    private let windParticleColor = CGColor(gray: 0.33, alpha: 0.2)
    private let windParticleScale = 1.0
    private let velocityScale = 0.33
    private let velocityRangeMultiplier = 0.2
    private let emitterWidth: CGFloat = 10.0
    private let windParticleBirthRateMultiplier: Float = 15.0
    
    @Environment(\.self) var environment
    
    init(frame: CGRect, winds: [Double : Double]?) {
        self.frame = frame
        self.winds = winds
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        rebuildWindEmittersIfNeeded(inView: uiView)
        uiView.windEmitters.forEach { updateWindEmitterPosition($0) }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: frame)
        
        rebuildWindEmittersIfNeeded(inView: view)
                
        return view
    }
    
    private func rebuildWindEmittersIfNeeded(inView view: UIView) {
        let wind = windByRange
        
        let existingWind = view.windEmitters.reduce(into: [WindSpan:Double]()) {
            $0[$1.windSpan!] = $1.windVelocity!
        }
        
        if existingWind != wind {
            view.windEmitters.forEach { $0.removeFromSuperlayer() }
            
            wind.compactMap { windEmitter(verticalSpan: $0, velocity: $1) }
                .forEach { view.layer.addSublayer($0) }
        }
    }
    
    private func updateWindEmitterPosition(_ windEmitter: WindEmitter) {
        guard let span = windEmitter.windSpan,
              let velocity = windEmitter.windVelocity else {
            return
        }
        
        windEmitter.emitterSize = windEmitterSize(verticalSpan: span)
        windEmitter.emitterPosition = windEmitterPosition(verticalSpan: span, velocity: velocity)
        windEmitter.frame = windEmitterFrame(verticalSpan: span)
    }
    
    private func windEmitter(verticalSpan: WindSpan, velocity: Double) -> WindEmitter? {
        let positiveVelocity = abs(velocity)

        guard positiveVelocity >= minimumWindToAnimate else {
            return nil
        }
        
        let screenScale = UIScreen.main.scale
        let emitter = WindEmitter()
        emitter.windSpan = verticalSpan
        emitter.windVelocity = velocity
        emitter.emitterShape = .rectangle
        emitter.contentsScale = screenScale
        
        // Prevent all wind emitters from weirdly aligning at first appearance
        emitter.seed = UInt32(verticalSpan.hashValue & Int(UInt32.max))
        
        let cell = CAEmitterCell()
        cell.contentsScale = UIScreen.main.scale
        cell.contents = UIImage(named: "WindParticle", in: nil, compatibleWith: nil)?.cgImage
        cell.color = windParticleColor
        cell.scale = windParticleScale
        cell.velocity = screenScale * velocity * velocityScale
        cell.velocityRange = velocityRangeMultiplier * positiveVelocity
        cell.lifetime = Float(screenScale * frame.size.width / (velocityScale * positiveVelocity - positiveVelocity * velocityRangeMultiplier * velocityScale))
        cell.birthRate =  Float((verticalSpan.upperBound - verticalSpan.lowerBound) * frame.size.height) * windParticleBirthRateMultiplier / cell.lifetime
        
        emitter.emitterCells = [cell]
        
        return emitter
    }
    
    private func windEmitterSize(verticalSpan: WindSpan) -> CGSize {
        CGSize(
            width: emitterWidth,
            height: UIScreen.main.scale * (verticalSpan.upperBound - verticalSpan.lowerBound) * frame.size.height
        )
    }
    
    private func windEmitterFrame(verticalSpan: WindSpan) -> CGRect {
        CGRect(
            x: 0.0,
            y: verticalSpan.lowerBound * frame.size.height,
            width: frame.size.width,
            height: windEmitterSize(verticalSpan: verticalSpan).height
        )
    }
    
    private func windEmitterPosition(verticalSpan: WindSpan, velocity: Double) -> CGPoint {
        CGPoint(
            x: velocity >= 0.0 ? -emitterWidth : frame.size.width,
            y: 0.0
        )
    }
    
    private var windByRange: [WindSpan: Double] {
        guard let winds = winds else {
            return [:]
        }
        
        let windHeights = [Double](winds.keys).filter({ (0.0...1.0).contains($0) }).sorted()
        
        return stride(from: 0, to: Int(windHeights.count), by: 1).reduce(into: [WindSpan: Double]()) {
            let height = windHeights[$1]
            let beforeHeight = $1 > 0 ? windHeights[$1 - 1] : 0.0
            let afterHeight = $1 < (windHeights.count - 1) ? windHeights[$1 + 1] : 1.0
            let halfBefore = beforeHeight > 0.0 ? height - ((height - beforeHeight) / 2.0) : windHeights[0]
            let halfAfter = afterHeight < 1.0 ? height + ((afterHeight - height) / 2.0) : 1.0
            
            $0[halfBefore...halfAfter] = winds[height]!
        }
    }
}

#Preview {
    GeometryReader { geometry in
        AnimatedWindView(
            frame: CGRect(origin: .zero, size: geometry.size),
            winds: [
                0.0: -25.0,
                0.1: -15.0,
                0.25: -5.0,
                0.4: 0.0,
                0.5: 25.0,
                0.75: 40.0
            ]
        )
    }
}
