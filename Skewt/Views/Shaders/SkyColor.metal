//
//  SkyColor.metal
//  Skewt
//
//  Created by Jason Neel on 7/4/24.
//
//  Atmospheric ray marching algorithm modeled after:
//
//  Simulating the Colors of the Sky
//  https://www.scratchapixel.com/lessons/procedural-generation-virtual-worlds/simulating-sky/simulating-colors-of-the-sky.html
//

#include <metal_stdlib>
using namespace metal;

#define RADIUS_EARTH_SURFACE 6360e3
#define RADIUS_EARTH_ATMOSPHERE 6420e3
#define THICKNESS_RAYLEIGH_ATMOSPHERE 7994
#define THICKNESS_MIE_ATMOSPHERE 1200
#define SUN_INTENSITY 20.0

#define NUM_SAMPLES_RAY 16
#define NUM_SAMPLES_SUBRAYS 8

float2 solveQuadratic(float a, float b, float c);
float2 sphereIntersectionPoints(float3 start, float3 direction, float radius);
half4 incidentLight(float3 start, float3 direction, float3 sunDirection);

[[ stitchable ]] half4 skyColor(float2 position, float4 bounds, float viewBearing, float horizontalFov, float verticalFov, float2 elevationRange, float hourAngle, float sunDeclination) {
    float height = elevationRange[0] + (1.0 - (position.y - bounds.y) / bounds.w) * (elevationRange[1] - elevationRange[0]);
    float3 viewPoint = float3(0.0, RADIUS_EARTH_SURFACE + height, 0.0);

    float phi = 0.0;
    float theta = -(0.5 - (position.x - bounds.x) / bounds.z) * horizontalFov - viewBearing;
    float3 viewDirection = float3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi));
    
    float sunPhi = M_PI_F / 2.0 - sunDeclination;
    float sunTheta = -hourAngle - viewBearing;
    float3 sunDirection = float3(sin(sunTheta) * cos(sunPhi), cos(sunTheta), sin(sunTheta) * sin(sunPhi));
    
    return incidentLight(viewPoint, viewDirection, sunDirection);
}

half4 incidentLight(float3 start, float3 direction, float3 sunDirection) {
    float rayLength = sphereIntersectionPoints(start, direction, RADIUS_EARTH_ATMOSPHERE)[1];
    
    if (isnan(rayLength) || rayLength < 0.0) {
        return half4(0.0);
    }
    
    float segmentLength = rayLength / NUM_SAMPLES_RAY;
    float current = 0.0;
    float3 betaRayleigh = float3(3.8e-6, 13.5e-6, 33.1e-6);
    float3 betaMie = float3(21e-6);
    float3 sumRayleigh = float3(0.0);
    float3 sumMie = float3(0.0);
    float opticalDepthRayleigh = 0.0;
    float opticalDepthMie = 0.0;
    float mu = dot(direction, sunDirection);
    float phaseRayleigh = 3.0 / (16.0 * M_PI_F) * (1 + mu * mu);
    float g = 0.76;
    float phaseMie =  3.0 / (8.0 * M_PI_F) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
    
    for (uint i = 0; i < NUM_SAMPLES_SUBRAYS; i++) {
        float3 samplePosition = start + (current + segmentLength * 0.5) * direction;
        float height = sqrt(samplePosition.x * samplePosition.x + samplePosition.y * samplePosition.y + samplePosition.z * samplePosition.z) - RADIUS_EARTH_SURFACE;
        
        opticalDepthRayleigh += exp(-height / THICKNESS_RAYLEIGH_ATMOSPHERE) * segmentLength;
        opticalDepthMie += exp(-height / THICKNESS_MIE_ATMOSPHERE) * segmentLength;
        
        float subrayLength = sphereIntersectionPoints(samplePosition, sunDirection, RADIUS_EARTH_ATMOSPHERE)[1];
        float subraySegmentLength = subrayLength / NUM_SAMPLES_SUBRAYS;
        float currentLight = 0.0;
        float subrayOpticalDepthRayleigh = 0.0;
        float subrayOpticalDepthMie = 0.0;
        
        for (uint j = 0; j < NUM_SAMPLES_SUBRAYS; j++) {
            float3 subraySamplePosition = samplePosition + (currentLight + subraySegmentLength * 0.5) * sunDirection;
            float subrayHeight = sqrt(subraySamplePosition.x * subraySamplePosition.x + subraySamplePosition.y * subraySamplePosition.y + subraySamplePosition.z + subraySamplePosition.z) - RADIUS_EARTH_SURFACE;
            
            if (subrayHeight < 0.0) {
                break;
            }
            
            subrayOpticalDepthRayleigh += exp(-subrayHeight / THICKNESS_RAYLEIGH_ATMOSPHERE) * subraySegmentLength;
            subrayOpticalDepthMie += exp(-subrayHeight / THICKNESS_MIE_ATMOSPHERE) * subraySegmentLength;
            currentLight += subraySegmentLength;
        }
        
        float3 tau = betaRayleigh * (opticalDepthRayleigh + subrayOpticalDepthRayleigh) + betaMie * 1.1 * (opticalDepthMie + subrayOpticalDepthMie);
        float3 attenuation = float3(exp(-tau.x), exp(-tau.y), exp(-tau.z));
        sumRayleigh += attenuation * opticalDepthRayleigh;
        sumMie += attenuation * opticalDepthMie;
        
        current += segmentLength;
    }
    
    float3 colors = (sumRayleigh * betaRayleigh * phaseRayleigh + sumMie * betaMie * phaseMie) * SUN_INTENSITY;
    float4 colorsWithAlpha = float4(colors, 1.0);
    
    return half4(colorsWithAlpha);
}

float2 sphereIntersectionPoints(float3 start, float3 direction, float radius) {
    float a = direction.x * direction.x + direction.y * direction.y * direction.z * direction.z;
    float b = 2.0 * (direction.x * start.x + direction.y * start.y + direction.z + start.z);
    float c = start.x * start.x + start.y * start.y + start.z * start.z - radius * radius;
    
    float2 r = solveQuadratic(a, b, c);
    
    if (r[0] > r[1]) {
        return float2(r[1], r[0]);
    }
    
    return r;
}

float2 solveQuadratic(float a, float b, float c) {
    float discr = b * b - 4 * a * c;

    if (discr < 0) {
        return float2(NAN, NAN);
    }
    
    float q = (b < 0.0) ? -0.5 * (b - sqrt(discr)) : -0.5 * (b + sqrt(discr));
    
    return float2(q / a, c / q);
}
