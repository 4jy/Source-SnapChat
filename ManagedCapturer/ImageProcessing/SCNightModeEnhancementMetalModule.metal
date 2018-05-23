//
//  SCNightModeEnhancementMetalModule.metal
//  Snapchat
//
//  Created by Chao Pang on 12/21/17.
//
//

#include <metal_stdlib>
using namespace metal;

typedef struct SampleBufferMetadata {
    int iosSpeedRating;
    float exposureTime;
    float brightness;
}SampleBufferMetadata;

kernel void kernel_night_mode_enhancement(texture2d<float, access::read> sourceYTexture [[texture(0)]],
                                   		  texture2d<float, access::read> sourceUVTexture [[texture(1)]],
                                          texture2d<float, access::write> destinationYTexture [[texture(2)]],
                                          texture2d<float, access::write> destinationUVTexture [[texture(3)]],
                                          constant SampleBufferMetadata &metaData [[buffer(0)]],
                                          uint2 gid [[thread_position_in_grid]],
                                          uint2 size [[threads_per_grid]]) {
    float valueY = sourceYTexture.read(gid).r;
    float2 valueUV = sourceUVTexture.read(gid).rg;

    float factor = 1.0 - metaData.brightness * 0.1;
    factor = max(min(factor, 1.3), 1.0);

    valueY = min(valueY * factor, 1.0);
    valueUV.rg = max(min((valueUV.rg - 0.5) * factor + 0.5, 1.0), 0.0);

    destinationYTexture.write(valueY, gid);
    destinationUVTexture.write(float4(valueUV.r, valueUV.g, 0, 0), gid);

}
