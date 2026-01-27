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
#define THICKNESS_RAYLEIGH_ATMOSPHERE 9000
#define THICKNESS_MIE_ATMOSPHERE 600
#define SUN_INTENSITY 80.0
#define EARTH_OBLIQUITY 0.409092804f  // 23.44 degrees

#define NUM_SAMPLES_RAY 16
#define NUM_SAMPLES_SUBRAYS 8

float4 incidentLight(float3 start, float3 direction, float3 sunDirection, float minimum, float maximum);
bool solveQuadratic(float a, float b, float c, thread float2 & x);
bool raySphereIntersect(float3 start, float3 direction, float radius, thread float2 & t);
float3 rotateY(float3 dir, float angle);
float3 rotateX(float3 dir, float angle);
float2 sampleFlattenedCube(float3 dir);

[[ stitchable ]] half4 skyColor(
                                float2 position,
                                float4 bounds,
                                float sunAzimuth,
                                float sunElevation,
                                float siderealTime,
                                float latitude,
                                float horizontalFov,
                                texture2d<half> starsTexture
                                ) {
    float3 viewPoint = float3(0.0, RADIUS_EARTH_SURFACE + 1.0, 0.0);
    
    float aspectRatio = bounds.z / bounds.w;
    float verticalFov = 2.0 * atan((1.0 / aspectRatio) * tan(horizontalFov / 2.0));
    
    float x = 2.0 * (position.x + bounds.x + 0.5) / bounds.z - 1.0;
    float y = 1.0 - 2.0 * (position.y + bounds.y + 0.5) / bounds.w;
    
    float elevation = (y + 1.0) * 0.5 * verticalFov;
    float azimuth = x * horizontalFov * 0.5;

    float3 viewDirection = float3(
                                  sin(azimuth) * cos(elevation),
                                  sin(elevation),
                                  -cos(azimuth) * cos(elevation)
                                  );
    float3 sunDirection = normalize(float3(
                                           sin(sunAzimuth) * cos(sunElevation),
                                           sin(sunElevation),
                                           -cos(sunAzimuth) * cos(sunElevation)
                                           ));
    
    // Since our sunlight casting using a non-pinhole camera (to allow the projection to be flat
    //  across the bottom of the view), we need to use a different direction for the star skybox,
    //  which uses a texture cube.
    float3 starViewDirection = normalize(float3(
                                                x * tan(horizontalFov * 0.5),
                                                y * tan(verticalFov * 0.5),
                                                -1.0
                                                ));
    
    starViewDirection = rotateX(starViewDirection, -EARTH_OBLIQUITY);
    starViewDirection = rotateY(starViewDirection, siderealTime);
    starViewDirection = rotateX(starViewDirection, latitude);
    
    float2 surfaceIntersection;
    float tMaximum = INFINITY;
    if (raySphereIntersect(viewPoint, viewDirection, RADIUS_EARTH_SURFACE, surfaceIntersection)) {
        if (surfaceIntersection[0] > 0.0) {
            tMaximum = surfaceIntersection[0];
        } else if (surfaceIntersection[1] > 0.0) {
            tMaximum = surfaceIntersection[1];
        }
    }
    
    float4 r = incidentLight(viewPoint, viewDirection, sunDirection, 0.0, tMaximum);
    float skyLuminance = dot(r.rgb, float3(0.2126, 0.7152, 0.0722));
    float starsMask = 1.0 - smoothstep(
                                       0.02,   // full night below this
                                       0.15,   // fully day above this
                                       skyLuminance
    );
    float horizonStarFade = smoothstep(
                                       0.0,
                                       8.0 * M_PI_F / 180.0,
                                       elevation
    );
    starsMask *= horizonStarFade;

    
    float2 starUV = sampleFlattenedCube(starViewDirection);
    uint2 textureSize = uint2(starsTexture.get_width(), starsTexture.get_height());
    uint2 texel = uint2(clamp(starUV.x * float(textureSize.x), 0.0, float(textureSize.x - 1)),
                        clamp(starUV.y * float(textureSize.y), 0.0, float(textureSize.y - 1)));

    float4 texelColor = float4(starsTexture.read(texel));
    
    float3 color = r.rgb + texelColor.rgb * starsMask;
    return half4(float4(color, 1.0));
}

float4 incidentLight(float3 start, float3 direction, float3 sunDirection, float tMinimum, float tMaximum) {
    float2 t;
    
    if (!raySphereIntersect(start, direction, RADIUS_EARTH_ATMOSPHERE, t) || t[1] < 0.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
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
    
    for (uint i = 0; i < NUM_SAMPLES_RAY; i++) {
        float3 samplePosition = start + (current + segmentLength * 0.5) * direction;
        float height = length(samplePosition) - RADIUS_EARTH_SURFACE;
        
        float2 tEarthShadow;
        if (raySphereIntersect(samplePosition, sunDirection, RADIUS_EARTH_SURFACE, tEarthShadow) && tEarthShadow[1] > 0.0) {
            continue;
        }
        
        opticalDepthRayleigh += exp(-height / THICKNESS_RAYLEIGH_ATMOSPHERE) * segmentLength;
        opticalDepthMie += exp(-height / THICKNESS_MIE_ATMOSPHERE) * segmentLength;
        
        float2 tLight;
        if (!raySphereIntersect(samplePosition, sunDirection, RADIUS_EARTH_ATMOSPHERE, tLight) || (tLight[1] <= 0.0)) {
            continue;
        }
        
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
            float localRayleigh = exp(-height / THICKNESS_RAYLEIGH_ATMOSPHERE);
            float localMie = exp(-height / THICKNESS_MIE_ATMOSPHERE);
            sumRayleigh += attenuation * localRayleigh * segmentLength;
            sumMie += attenuation * localMie * segmentLength;
        }
        
        current += segmentLength;
    }
    
    float3 colors = (sumRayleigh * betaRayleigh * phaseRayleigh + sumMie * betaMie * phaseMie) * SUN_INTENSITY;
    
    float sunLuminance = dot(colors, float3(0.2126, 0.7152, 0.0722));
    float sunWeight = smoothstep(0.01, 0.08, sunLuminance);
        
    float viewUp = saturate(direction.y);
    float horizon = 1.0 - viewUp;

    float3 zenithNight = float3(0.04, 0.06, 0.12);
    float3 horizonNight = float3(0.067, 0.125, 0.302);

    float3 nightColor = mix(zenithNight, horizonNight, pow(horizon, 1.5));
    
    // Tone mapping
    colors = 1.0 - exp(-colors);

    // Apply night coloring
    colors = mix(nightColor, colors, sunWeight);
    
    return float4(colors, 1.0);
}

bool solveQuadratic(float a, float b, float c, thread float2 & x) {
    float discriminant = b * b - 4.0 * a * c;
    
    if (discriminant < 0.0) {
        return false;
    }
    
    float q = (b < 0.0) ? -0.5 * (b - sqrt(discriminant)) : -0.5 * (b + sqrt(discriminant));
    
    x = float2(q / a, c / q);
    return true;
}

bool raySphereIntersect(float3 start, float3 direction, float radius, thread float2 & t) {
    float a = dot(direction, direction);
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

float3 rotateY(float3 dir, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    
    return float3(
        dir.x * c + dir.z * s,
        dir.y,
        -dir.x * s + dir.z * c
    );
}

float3 rotateX(float3 dir, float angle)
{
    float s = sin(angle);
    float c = cos(angle);

    return float3(
        dir.x,
        c * dir.y - s * dir.z,
        s * dir.y + c * dir.z
    );
}

float2 sampleFlattenedCube(float3 dir) {
    float absX = fabs(dir.x);
    float absY = fabs(dir.y);
    float absZ = fabs(dir.z);
    
    float u;
    float v;
    int faceIndex;
    
    if (absX >= absY && absX >= absZ) {
        if (dir.x > 0) {
            u = -dir.z / absX;
            v = dir.y / absX;
            faceIndex = 0;
        } else {
            u = dir.z / absX;
            v = dir.y / absX;
            faceIndex = 1;
        }
    } else if (absY >= absX && absY >= absZ) {
        if (dir.y > 0) {
            u = dir.x / absY;
            v = -dir.z / absY;
            faceIndex = 2;
        } else {
            u = dir.x / absY;
            v = dir.z / absY;
            faceIndex = 3;
        }
    } else {
        if (dir.z > 0) {
            u = dir.x / absZ;
            v = dir.y / absZ;
            faceIndex = 4;
        } else {
            u = -dir.x / absZ;
            v = dir.y / absZ;
            faceIndex = 5;
        }
    }
    
    // Convert from [-1,1] to [0,1]
    u = 0.5 * (u + 1.0);
    v = 0.5 * (v + 1.0);

    // Flatten horizontally: each face is 1/6 of width
    u = (faceIndex + u) / 6.0;

    return float2(u, v);
}

