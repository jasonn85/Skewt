//
//  WindBarb.swift
//  Skewt
//
//  Created by Jason Neel on 8/8/23.
//

import SwiftUI

struct WindBarb: Shape {
    let bearingInDegrees: Int
    let speed: Int
    
    var length: CGFloat = 50.0
    
    var endRadius: CGFloat? = nil
    
    var barbSpacing: CGFloat = 4.0
    var barbLength: CGFloat = 10.0
    
    private enum Barb {
        case flag
        case full
        case half
    }
    
    func path(in rect: CGRect) -> Path {
        let halfLength = length / 2.0
        
        let dx = halfLength * sin(bearing)
        let dy = halfLength * cos(bearing)
        
        let center = CGPoint(x: rect.midX, y: rect.minY)
        let p1 = CGPoint(x: center.x - dx, y: center.y - dy)
        let p2 = CGPoint(x: center.x + dx, y: center.y + dy)
        
        return Path() { path in
            path.move(to: p1)
            path.addLine(to: p2)
            
            path.move(to: p1)
            
            for barb in barbs {
                let startingPoint = path.currentPoint!
                let offset = barbOffset(barb)
                
                path.addLine(to: CGPoint(
                    x: startingPoint.x + offset.x,
                    y: startingPoint.y + offset.y
                ))
                
                if case .flag = barb {
                    path.addLine(to: CGPoint(
                        x: startingPoint.x + barbSpacingOffset.x,
                        y: startingPoint.y + barbSpacingOffset.y
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
                let origin = CGPoint(x: p2.x - halfRadius, y: p2.y - halfRadius)

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
        (x: barbSpacing * sin(bearing), y: barbSpacing * cos(bearing))
    }
    
    private func barbOffset(_ barb: Barb) -> (x: CGFloat, y: CGFloat) {
        let length: CGFloat
        
        switch barb {
        case .flag, .full:
            length = barbLength
        case .half:
            length = barbLength / 2.0
        }
        
        let barbBearing = bearing + .pi / 2.0
        
        return (x: length * sin(barbBearing), y: length * cos(barbBearing))
    }
    
    private var barbs: [Barb] {
        var result: [Barb] = []

        result.append(contentsOf: repeatElement(.flag, count: speed / 50))
        result.append(contentsOf: repeatElement(.full, count: (speed % 50) / 10))
        result.append(contentsOf: repeatElement(.half, count: (speed % 10) / 5))
        
        return result
    }
}

struct WindBarb_Previews: PreviewProvider {
    static var previews: some View {
        let dDegrees = 30
        let speeds = [0, 5, 10, 25, 50, 135, 150]
        
        HStack {
            ForEach(Array(stride(from: 0, to: 360 - dDegrees, by: dDegrees)), id: \.self) { bearing in
                VStack {
                    ForEach(speeds, id: \.self) { speed in
                        WindBarb(bearingInDegrees: bearing, speed: speed)
                            .stroke(.black, lineWidth: 2.0)
                    }
                }
            }
        }
    }
}
