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
    
    private let windParticleColor = CGColor(gray: 0.5, alpha: 0.25)
    private let windParticleScale = 0.5
    private let windParticleLifetime: Float = 100.0
    private let velocityScale = 1.0
    private let velocityRangeMultiplier = 0.1
    private let birthRate: Float = 100.0
    private let emitterWidth: CGFloat = 10.0
    
    @Environment(\.self) var environment

    func updateUIView(_ uiView: UIView, context: Context) {
        removeAndRecreateLayers(inView: uiView)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: frame)
        removeAndRecreateLayers(inView: view)
        
        return view
    }
    
    private func removeAndRecreateLayers(inView view: UIViewType) {
        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        let gradient = CAGradientLayer()
        gradient.frame = frame
        gradient.colors = skyColors.compactMap { $0.resolve(in: environment).cgColor }
        gradient.startPoint = skyGradientStart
        gradient.endPoint = skyGradientEnd
        
        view.layer.addSublayer(gradient)
        
        windByRange?.forEach {
            view.layer.addSublayer(windEmitter(verticalSpan: $0.0, velocity: $0.1))
        }
    }
    
    private func windEmitter(verticalSpan: ClosedRange<CGFloat>, velocity: Double) -> CAEmitterLayer {
        let emitterSize = CGSize(
            width: emitterWidth,
            height: (verticalSpan.upperBound - verticalSpan.lowerBound) * frame.size.height
        )
        
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(
            x: 0.0,
            y: verticalSpan.lowerBound * frame.size.height,
            width: frame.size.width,
            height: emitterSize.height
        )
        
        emitter.emitterShape = .rectangle
        emitter.emitterSize = emitterSize
        emitter.emitterPosition = CGPoint(
            x: velocity >= 0.0 ? -emitterWidth : frame.size.width + emitterWidth,
            y: (verticalSpan.upperBound + verticalSpan.lowerBound) / 2.0 * frame.size.height
        )
        
        let cell = CAEmitterCell()
        cell.contents = UIImage(named: "WindParticle", in: nil, compatibleWith: nil)?.cgImage
        cell.color = windParticleColor
        cell.scale = windParticleScale
        cell.velocity = velocity * velocityScale
        cell.velocityRange = velocityRangeMultiplier * velocity
        cell.birthRate = birthRate * Float(verticalSpan.upperBound - verticalSpan.lowerBound)
        cell.lifetime = windParticleLifetime
        
        emitter.emitterCells = [cell]
        
        return emitter
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
