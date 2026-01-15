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

#define PI 3.1415926535
#define RADIUS_EARTH_SURFACE 6360e3
#define RADIUS_EARTH_ATMOSPHERE 6420e3
#define THICKNESS_RAYLEIGH_ATMOSPHERE 7994
#define THICKNESS_MIE_ATMOSPHERE 1200
#define SUN_INTENSITY 20.0

#define NUM_SAMPLES_RAY 16
#define NUM_SAMPLES_SUBRAYS 8

half4 incidentLight(float3 start, float3 direction, float3 sunDirection, float minimum, float maximum);
bool solveQuadratic(float a, float b, float c, thread float2 & x);
bool raySphereIntersect(float3 start, float3 direction, float radius, thread float2 & t);

[[ stitchable ]] half4 skyColor(float2 position, float4 bounds, float sunAzimuth, float sunElevation, float horizontalFov) {
    float3 viewPoint = float3(0.0, RADIUS_EARTH_SURFACE, 0.0);
    
    float aspectRatio = bounds.z / bounds.w;
    float verticalFov = 2.0 * atan((1.0 / aspectRatio) * tan(horizontalFov / 2.0));
    
    float x = 2.0 * (position.x + bounds.x + 0.5) / bounds.z - 1.0;
    float y = 1.0 - (position.y + bounds.y + 0.5) / bounds.w;
    
    float3 viewDirection = normalize(float3(x * tan(horizontalFov / 2.0), y * tan(verticalFov / 2.0), -1.0));
    float3 sunDirection = normalize(float3(sin(sunAzimuth) * cos(sunElevation), sin(sunElevation), -cos(sunAzimuth) * cos(sunElevation)));
    
    float2 surfaceIntersection;
    float tMaximum = INFINITY;
    if (raySphereIntersect(viewPoint, viewDirection, RADIUS_EARTH_SURFACE, surfaceIntersection) && surfaceIntersection[1] > 0.0) {
        tMaximum = max(0.0, surfaceIntersection[0]);
    }
    
    half4 r = incidentLight(viewPoint, viewDirection, sunDirection, 0.0, tMaximum);
    
    return r;
}

half4 incidentLight(float3 start, float3 direction, float3 sunDirection, float tMinimum, float tMaximum) {
    float2 t;
    
    if (!raySphereIntersect(start, direction, RADIUS_EARTH_ATMOSPHERE, t) || t[1] < 0.0) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    
    if (t[0] > tMinimum && t[0] > 0.0) {
        tMinimum = t[0];
    }
    
    if (t[1] < tMaximum) {
        tMaximum = t[1];
    }
    
    float segmentLength = (tMaximum - tMinimum) / NUM_SAMPLES_RAY;
    float current = tMinimum;
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
        float height = length(samplePosition) - RADIUS_EARTH_SURFACE;
        
        opticalDepthRayleigh += exp(-height / THICKNESS_RAYLEIGH_ATMOSPHERE) * segmentLength;
        opticalDepthMie += exp(-height / THICKNESS_MIE_ATMOSPHERE) * segmentLength;
        
        float2 tLight;
        raySphereIntersect(samplePosition, sunDirection, RADIUS_EARTH_ATMOSPHERE, tLight);
        float subraySegmentLength = tLight[1] / NUM_SAMPLES_SUBRAYS;
        float currentLight = 0.0;
        float subrayOpticalDepthRayleigh = 0.0;
        float subrayOpticalDepthMie = 0.0;
        bool underground = false;
        
        for (uint j = 0; j < NUM_SAMPLES_SUBRAYS; j++) {
            float3 subraySamplePosition = samplePosition + (currentLight + subraySegmentLength * 0.5) * sunDirection;
            float subrayHeight = length(subraySamplePosition) - RADIUS_EARTH_SURFACE;
            
            if (subrayHeight < 0.0) {
                underground = true;
                break;
            }
            
            subrayOpticalDepthRayleigh += exp(-subrayHeight / THICKNESS_RAYLEIGH_ATMOSPHERE) * subraySegmentLength;
            subrayOpticalDepthMie += exp(-subrayHeight / THICKNESS_MIE_ATMOSPHERE) * subraySegmentLength;
            currentLight += subraySegmentLength;
        }
        
        if (!underground) {
            float3 tau = betaRayleigh * (opticalDepthRayleigh + subrayOpticalDepthRayleigh) + betaMie * 1.1 * (opticalDepthMie + subrayOpticalDepthMie);
            float3 attenuation = float3(exp(-tau.x), exp(-tau.y), exp(-tau.z));
            sumRayleigh += attenuation * opticalDepthRayleigh;
            sumMie += attenuation * opticalDepthMie;
        }
        
        current += segmentLength;
    }
    
    float3 colors = (sumRayleigh * betaRayleigh * phaseRayleigh + sumMie * betaMie * phaseMie) * SUN_INTENSITY;
    float4 colorsWithAlpha = float4(colors, 1.0);
    
    return half4(colorsWithAlpha);
}

bool solveQuadratic(float a, float b, float c, thread float2 & x) {
    if (b == 0.0) {
        if (a == 0.0) {
            return false;
        }
        
        x = float2(0.0, sqrt(-c / a));
        return true;
    }
    
    float discriminant = b * b - 4.0 * a * c;
    
    if (discriminant < 0.0) {
        return false;
    }
    
    float q = (b < 0.0) ? -0.5 * (b - sqrt(discriminant)) : -0.5 * (b + sqrt(discriminant));
    
    x = float2(q / a, c / q);
    return true;
}

bool raySphereIntersect(float3 start, float3 direction, float radius, thread float2 & t) {
    float a = direction.x * direction.x + direction.y * direction.y + direction.z + direction.z;
    float b = 2.0 * (direction.x * start.x + direction.y * start.y + direction.z * start.z);
    float c = start.x * start.x + start.y * start.y + start.z * start.z - radius * radius;
    
    if (!solveQuadratic(a, b, c, t)) {
        return false;
    }
    
    if (t[0] > t[1]) {
        float t1 = t[1];
        t[1] = t[0];
        t[0] = t1;
    }
    
    return true;
}
