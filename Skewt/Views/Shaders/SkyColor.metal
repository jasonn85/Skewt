//
//  SkyColor.metal
//  Skewt
//
//  Created by Jason Neel on 7/4/24.
//

#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] half4 skyColor(float2 position, float4 bounds) {
    half4 highBlue = half4(0.093, 0.312, 1.0, 1.0);
    half4 lowBlue = half4(0.656, 0.861, 0.980, 1.0);
    
    return highBlue + (lowBlue - highBlue) * (position.y / bounds.w);
}
