#include <metal_stdlib>
using namespace metal;

constexpr sampler linear(filter::linear,coord::pixel,address::clamp_to_edge);

kernel void processimage(
    texture2d<float,access::sample> src[[texture(0)]],
    texture2d<float,access::write> dst[[texture(1)]],
    uint2 gid[[thread_position_in_grid]]) {
    
    float2 texcoord = float2(gid)+0.5;    
    dst.write(src.sample(linear,texcoord),gid);
    
}
