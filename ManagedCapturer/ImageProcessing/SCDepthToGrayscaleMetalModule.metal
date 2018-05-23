//
//  SCDepthToGrayscaleMetalModule.metal
//  Snapchat
//
//  Created by Brian Ng on 12/7/17.
//

#include <metal_stdlib>
using namespace metal;

typedef struct DepthToGrayscaleRenderData {
    float depthRange;
    float depthOffset;
} DepthToGrayscaleRenderData;

kernel void kernel_depth_to_grayscale(texture2d<float, access::read> sourceDepthTexture[[texture(0)]],
                                      texture2d<float, access::write> destinationYTexture [[texture(1)]],
                                      texture2d<float, access::write> destinationUVTexture [[texture(2)]],
                                      constant DepthToGrayscaleRenderData &renderData [[buffer(0)]],
                                      uint2 gid [[thread_position_in_grid]],
                                      uint2 size [[threads_per_grid]]) {
    float depthValue = sourceDepthTexture.read(uint2(gid.x/4, gid.y/4)).r;
    float normalizedDepthValue = (depthValue - renderData.depthOffset) / renderData.depthRange;
    
    destinationYTexture.write(normalizedDepthValue, gid);
    destinationUVTexture.write(float4(0.5, 0.5, 0, 0), gid);
}


