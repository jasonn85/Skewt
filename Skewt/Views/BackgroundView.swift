//
//  BackgroundView.swift
//  Skewt
//
//  Created by Jason Neel on 11/23/23.
//

import SwiftUI

struct BackgroundView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    let frame: CGRect
    let skyGradientStart: CGPoint = CGPoint(x: 0.5, y: 0.0)
    let skyGradientEnd: CGPoint = CGPoint(x: 0.5, y: 1.0)
    let skyColors: [Color] = [Color("HighSkyBlue"), Color("LowSkyBlue")]
    
    /// Dictionary of 1d wind data keyed by [0...1] height
    let winds: [Double: Double]?
    let minimumWind = 5.0
    
    private let gradientName = "backgroundGradient"
    private let windSpanKey = "windVerticalSpan"
    private let windVelocityKey = "windVelocity"

    private let windParticleColor = CGColor(gray: 0.5, alpha: 0.2)
    private let windParticleScale = 0.5
    private let velocityScale = 1.25
    private let velocityRangeMultiplier = 0.1
    private let emitterWidth: CGFloat = 10.0
    
    @Environment(\.self) var environment

    func updateUIView(_ uiView: UIView, context: Context) {
        updateLayers(inView: uiView)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: frame)
        updateLayers(inView: view)
        
        return view
    }
    
    private func updateLayers(inView view: UIViewType) {
        var gradient: CAGradientLayer? = view.layer.sublayers?.first(where: { $0.name == gradientName }) as? CAGradientLayer
        
        if gradient == nil {
            gradient = CAGradientLayer()
            gradient!.name = gradientName
            view.layer.addSublayer(gradient!)
        }
        
        gradient!.frame = frame
        gradient!.colors = skyColors.compactMap { $0.resolve(in: environment).cgColor }
        gradient!.startPoint = skyGradientStart
        gradient!.endPoint = skyGradientEnd
        
        var windEmitters: [CAEmitterLayer] = (view.layer.sublayers ?? []).filter({ $0.value(forKey: windSpanKey) != nil }) as! [CAEmitterLayer]
        
        if windEmitters.count == 0 {
            windEmitters = windByRange?.compactMap { windEmitter(verticalSpan: $0.0, velocity: $0.1) } ?? []
            windEmitters.forEach { view.layer.addSublayer($0) }
        }
        
        windEmitters.forEach {
            let span = $0.value(forKey: windSpanKey) as! ClosedRange<CGFloat>
            let velocity = $0.value(forKey: windVelocityKey) as! Double
            
            $0.emitterSize = windEmitterSize(verticalSpan: span)
            $0.emitterPosition = windEmitterPosition(verticalSpan: span, velocity: velocity)
            $0.frame = windEmitterFrame(verticalSpan: span)
        }
    }
    
    private func windEmitter(verticalSpan: ClosedRange<CGFloat>, velocity: Double) -> CAEmitterLayer? {
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
    
    private func windEmitterSize(verticalSpan: ClosedRange<CGFloat>) -> CGSize {
        CGSize(
            width: emitterWidth,
            height: (verticalSpan.upperBound - verticalSpan.lowerBound) * frame.size.height
        )
    }
    
    private func windEmitterFrame(verticalSpan: ClosedRange<CGFloat>) -> CGRect {
        CGRect(
            x: 0.0,
            y: verticalSpan.lowerBound * frame.size.height,
            width: frame.size.width,
            height: windEmitterSize(verticalSpan: verticalSpan).height
        )
    }
    
    private func windEmitterPosition(verticalSpan: ClosedRange<CGFloat>, velocity: Double) -> CGPoint {
        CGPoint(
            x: velocity >= 0.0 ? -emitterWidth : frame.size.width,
            y: (verticalSpan.upperBound + verticalSpan.lowerBound) / 2.0 * frame.size.height
        )
    }
    
    private var windByRange: [(ClosedRange<CGFloat>, Double)]? {
        guard let winds = winds else {
            return nil
        }
        
        let windHeights = [Double](winds.keys).filter({ (0.0...1.0).contains($0) }).sorted()
        
        return stride(from: 0, to: Int(windHeights.count), by: 1).map {
            let height = windHeights[$0]
            let beforeHeight = $0 > 0 ? windHeights[$0 - 1] : 0.0
            let afterHeight = $0 < (windHeights.count - 1) ? windHeights[$0 + 1] : 1.0
            let halfBefore = beforeHeight > 0.0 ? height - ((height - beforeHeight) / 2.0) : 0.0
            let halfAfter = afterHeight < 1.0 ? height + ((afterHeight - height) / 2.0) : 1.0
            
            return (halfBefore...halfAfter, winds[height]!)
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
