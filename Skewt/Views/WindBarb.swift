//
//  WindBarb.swift
//  Skewt
//
//  Created by Jason Neel on 8/8/23.
//

import SwiftUI

struct WindBarb: Shape {
    let bearingInDegrees: Int
    let speed: Double
    
    var length: CGFloat = 50.0
    
    var endRadius: CGFloat? = nil
    
    var tickSpacing: CGFloat = 4.0
    var tickLength: CGFloat = 10.0
    
    private enum Barb {
        case flag
        case full
        case half
        case blank
    }
    
    func path(in rect: CGRect) -> Path {
        let halfLength = length / 2.0
        
        let dx = halfLength * sin(bearing)
        let dy = halfLength * cos(bearing)
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let upwindPoint = CGPoint(x: center.x - dx, y: center.y - dy)
        let downwindPoint = CGPoint(x: center.x + dx, y: center.y + dy)
        
        guard speed >= 5 else {
            return Path() { path in
                let radius = length / 4.0
                
                path.addEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2.0,
                    height: radius * 2.0
                ))
            }
        }
        
        return Path() { path in
            path.move(to: upwindPoint)
            path.addLine(to: downwindPoint)
            
            path.move(to: upwindPoint)
            
            for barb in barbs {
                let startingPoint = path.currentPoint!
                let offset = barbOffset(barb)
                
                if let offset = offset {
                    path.addLine(to: CGPoint(
                        x: startingPoint.x + offset.x,
                        y: startingPoint.y + offset.y
                    ))
                }
                
                if case .flag = barb {
                    path.addLine(to: CGPoint(
                        x: startingPoint.x - barbSpacingOffset.x,
                        y: startingPoint.y - barbSpacingOffset.y
                    ))
                    
                    path.move(to: CGPoint(
                        x: startingPoint.x + barbSpacingOffset.x / 4.0,
                        y: startingPoint.y + barbSpacingOffset.y / 4.0
                    ))
                } else {
                    path.move(to: startingPoint)
                }
                
                path.move(to: CGPoint(
                    x: path.currentPoint!.x + barbSpacingOffset.x,
                    y: path.currentPoint!.y + barbSpacingOffset.y
                ))
            }

            if let endRadius = endRadius {
                let halfRadius = endRadius / 2.0
                let origin = CGPoint(x: downwindPoint.x - halfRadius, y: downwindPoint.y - halfRadius)

                path.addEllipse(in: CGRect(
                    origin: origin,
                    size: CGSize(width: endRadius, height: endRadius))
                )
            }
        }
    }
    
    private var bearing: CGFloat {
        Double(bearingInDegrees) * .pi / 180.0
    }
    
    private var barbSpacingOffset: (x: CGFloat, y: CGFloat) {
        (x: tickSpacing * sin(bearing), y: tickSpacing * cos(bearing))
    }
    
    private func barbOffset(_ barb: Barb) -> (x: CGFloat, y: CGFloat)? {
        let length: CGFloat
        
        switch barb {
        case .flag, .full:
            length = tickLength
        case .half:
            length = tickLength / 2.0
        case .blank:
            return nil
        }
        
        let barbBearing = bearing + 1.2 * .pi / 2.0
        
        return (x: length * sin(barbBearing), y: length * cos(barbBearing))
    }
    
    private var barbs: [Barb] {
        var result: [Barb] = []

        result.append(contentsOf: repeatElement(.flag, count: Int(speed) / 50))
        result.append(contentsOf: repeatElement(.full, count: (Int(speed) % 50) / 10))
        result.append(contentsOf: repeatElement(.half, count: (Int(speed) % 10) / 5))
        
        switch result.first {
        case .flag, .half:
            result.insert(.blank, at: 0)
        case .blank, .full, .none:
            break
        }
        
        return result
    }
}

struct WindBarb_Previews: PreviewProvider {
    static var previews: some View {
        let dDegrees = 30
        let speeds = [2, 5, 10, 25, 50, 135, 150]
        
        HStack {
            ForEach(Array(stride(from: 0, to: 360 - dDegrees, by: dDegrees)), id: \.self) { bearing in
                VStack {
                    ForEach(speeds, id: \.self) { speed in
                        WindBarb(bearingInDegrees: bearing, speed: Double(speed))
                            .stroke(.black, lineWidth: 2.0)
                            .fill(speed >= 5 ? .black : .clear)
                            .border(.black)
                    }
                }
            }
        }
    }
}
