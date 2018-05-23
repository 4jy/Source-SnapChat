//
//  SCExposureAdjustMetalModule.metal
//  Snapchat
//
//  Created by Michel Loenngren on 7/11/17.
//
//

#include <metal_stdlib>
using namespace metal;

kernel void kernel_exposure_adjust(texture2d<float, access::read> sourceYTexture [[texture(0)]],
                                   texture2d<float, access::read> sourceUVTexture [[texture(1)]],
                                   texture2d<float, access::write> destinationYTexture [[texture(2)]],
                                   texture2d<float, access::write> destinationUVTexture [[texture(3)]],
                                   uint2 gid [[thread_position_in_grid]],
                                   uint2 size [[threads_per_grid]]) {
    float valueY = sourceYTexture.read(gid).r;
    float2 valueUV = sourceUVTexture.read(gid).rg;

    float factor = 1.0 / pow(1.0 + valueY, 5) + 1.0;
    valueY *= factor;
    destinationYTexture.write(valueY, gid);
    destinationUVTexture.write(float4(valueUV.r, valueUV.g, 0, 0), gid);

}

kernel void kernel_exposure_adjust_nightvision(texture2d<float, access::read> sourceYTexture [[texture(0)]],
                                   texture2d<float, access::read> sourceUVTexture [[texture(1)]],
                                   texture2d<float, access::write> destinationYTexture [[texture(2)]],
                                   texture2d<float, access::write> destinationUVTexture [[texture(3)]],
                                   uint2 gid [[thread_position_in_grid]],
                                   uint2 size [[threads_per_grid]]) {
    float valueY = sourceYTexture.read(gid).r;
    
    float u =  0.5 - 0.368;
    float v = 0.5 - 0.291;
    
    destinationYTexture.write(valueY, gid);
    destinationUVTexture.write(float4(u, v, 0, 0), gid);
    
}

kernel void kernel_exposure_adjust_inverted_nightvision(texture2d<float, access::read> sourceYTexture [[texture(0)]],
                                               texture2d<float, access::read> sourceUVTexture [[texture(1)]],
                                               texture2d<float, access::write> destinationYTexture [[texture(2)]],
                                               texture2d<float, access::write> destinationUVTexture [[texture(3)]],
                                               uint2 gid [[thread_position_in_grid]],
                                               uint2 size [[threads_per_grid]]) {
    float valueY = sourceYTexture.read(gid).r;
    
    valueY = 1.0 - valueY;
    
    float u =  0.5 - 0.368;
    float v = 0.5 - 0.291;
    
    destinationYTexture.write(valueY, gid);
    destinationUVTexture.write(float4(u, v, 0, 0), gid);
    
}
