//
//  SCDepthBlurMetalModule.metal
//  Snapchat
//
//  Created by Brian Ng on 10/31/17.
//

#include <metal_stdlib>
using namespace metal;

struct DepthBlurRenderData {
    float depthRange;
    float depthOffset;
    float depthBlurForegroundThreshold;
    float depthBlurBackgroundThreshold;
};

kernel void kernel_depth_blur(texture2d<float, access::read> sourceYTexture [[texture(0)]],
                              texture2d<float, access::read> sourceUVTexture [[texture(1)]],
                              texture2d<float, access::read> sourceDepthTexture[[texture(2)]],
                              texture2d<float, access::read> sourceBlurredYTexture [[texture(3)]],
                              texture2d<float, access::write> destinationYTexture [[texture(4)]],
                              texture2d<float, access::write> destinationUVTexture [[texture(5)]],
                              constant DepthBlurRenderData &renderData [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]],
                              uint2 size [[threads_per_grid]]) {
    float2 valueUV = sourceUVTexture.read(gid).rg;
    float depthValue = sourceDepthTexture.read(uint2(gid.x/4, gid.y/4)).r;
    float normalizedDepthValue = (depthValue - renderData.depthOffset) / renderData.depthRange;
    float valueYUnblurred = sourceYTexture.read(gid).r;
    float valueYBlurred = sourceBlurredYTexture.read(gid).r;
    
    float valueY = 0;
    if (normalizedDepthValue > renderData.depthBlurForegroundThreshold) {
        valueY = valueYUnblurred;
    } else if (normalizedDepthValue < renderData.depthBlurBackgroundThreshold) {
        valueY = valueYBlurred;
    } else {
        float blendRange = renderData.depthBlurForegroundThreshold - renderData.depthBlurBackgroundThreshold;
        float normalizedBlendDepthValue = (normalizedDepthValue - renderData.depthBlurBackgroundThreshold) / blendRange;
        valueY = valueYUnblurred * normalizedBlendDepthValue + valueYBlurred * (1 - normalizedBlendDepthValue);
    }
    
    destinationYTexture.write(valueY, gid);
    destinationUVTexture.write(float4(valueUV.r, valueUV.g, 0, 0), gid);
}

