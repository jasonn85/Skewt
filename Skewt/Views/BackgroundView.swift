//
//  BackgroundView.swift
//  Skewt
//
//  Created by Jason Neel on 11/23/23.
//

import SwiftUI

fileprivate let windSpanKey = "windVerticalSpan"
fileprivate let windVelocityKey = "windVelocity"

fileprivate extension UIView {
    var windEmitters: [CAEmitterLayer] {
        (layer.sublayers ?? []).filter({ $0.value(forKey: windSpanKey) != nil }) as! [CAEmitterLayer]
    }
}

struct BackgroundView: UIViewRepresentable {
    typealias UIViewType = UIView
    private typealias WindSpan = ClosedRange<CGFloat>
    
    let frame: CGRect
    let skyGradientStart: CGPoint = CGPoint(x: 0.5, y: 0.0)
    let skyGradientEnd: CGPoint = CGPoint(x: 0.5, y: 1.0)
    let skyColors: [Color] = [Color("HighSkyBlue"), Color("LowSkyBlue")]
    
    /// Dictionary of 1d wind data keyed by [0...1] height
    let winds: [Double: Double]?
    let minimumWind = 5.0
    
    private let gradientName = "backgroundGradient"

    private let windParticleColor = CGColor(gray: 0.5, alpha: 0.2)
    private let windParticleScale = 0.5
    private let velocityScale = 1.25
    private let velocityRangeMultiplier = 0.1
    private let emitterWidth: CGFloat = 10.0
    
    @Environment(\.self) var environment

    func updateUIView(_ uiView: UIView, context: Context) {
        let gradient: CAGradientLayer? = uiView.layer.sublayers?.first(where: { $0.name == gradientName }) as? CAGradientLayer
        
        gradient!.frame = frame
        gradient!.colors = skyColors.compactMap { $0.resolve(in: environment).cgColor }
        gradient!.startPoint = skyGradientStart
        gradient!.endPoint = skyGradientEnd
        
        rebuildWindEmittersIfNeeded(inView: uiView)
        uiView.windEmitters.forEach { updateWindEmitter($0) }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: frame)

        let gradient = CAGradientLayer()
        gradient.name = gradientName
        view.layer.addSublayer(gradient)
        
        rebuildWindEmittersIfNeeded(inView: view)
                
        return view
    }
    
    private func rebuildWindEmittersIfNeeded(inView view: UIView) {
        let wind = windByRange
        let existingWindEmitters = view.windEmitters
        let existingWindRanges = Set(existingWindEmitters.compactMap({ $0.value(forKey: windSpanKey) as? WindSpan }))
    
        if existingWindRanges != Set(wind.keys) {
            existingWindEmitters.forEach { $0.removeFromSuperlayer() }
            
            wind.compactMap { windEmitter(verticalSpan: $0, velocity: $1) }
                .forEach { view.layer.addSublayer($0) }
        }
    }
    
    private func updateWindEmitter(_ windEmitter: CAEmitterLayer) {
        guard let span = windEmitter.value(forKey: windSpanKey) as? WindSpan,
              let velocity = windEmitter.value(forKey: windVelocityKey) as? Double else {
            return
        }
        
        windEmitter.emitterSize = windEmitterSize(verticalSpan: span)
        windEmitter.emitterPosition = windEmitterPosition(verticalSpan: span, velocity: velocity)
        windEmitter.frame = windEmitterFrame(verticalSpan: span)
    }
    
    private func windEmitter(verticalSpan: WindSpan, velocity: Double) -> CAEmitterLayer? {
        let positiveVelocity = abs(velocity)

        guard positiveVelocity >= minimumWind else {
            return nil
        }
        
        let emitter = CAEmitterLayer()
        emitter.setValue(verticalSpan, forKey: windSpanKey)
        emitter.setValue(velocity, forKey: windVelocityKey)
        emitter.emitterShape = .rectangle
        
        let cell = CAEmitterCell()
        cell.contents = UIImage(named: "WindParticle", in: nil, compatibleWith: nil)?.cgImage
        cell.color = windParticleColor
        cell.scale = windParticleScale
        cell.velocity = velocity * velocityScale
        cell.velocityRange = velocityRangeMultiplier * positiveVelocity
        cell.lifetime = Float(frame.size.width / (positiveVelocity - positiveVelocity * velocityRangeMultiplier))
        cell.birthRate = 25.0 / cell.lifetime
        
        emitter.emitterCells = [cell]
        
        return emitter
    }
    
    private func windEmitterSize(verticalSpan: WindSpan) -> CGSize {
        CGSize(
            width: emitterWidth,
            height: (verticalSpan.upperBound - verticalSpan.lowerBound) * frame.size.height
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
            y: (verticalSpan.upperBound + verticalSpan.lowerBound) / 2.0 * frame.size.height
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
            let halfBefore = beforeHeight > 0.0 ? height - ((height - beforeHeight) / 2.0) : 0.0
            let halfAfter = afterHeight < 1.0 ? height + ((afterHeight - height) / 2.0) : 1.0
            
            $0[halfBefore...halfAfter] = winds[height]!
        }
    }
}

#Preview {
    GeometryReader { geometry in
        BackgroundView(
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
