#version 430

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba32f, binding = 0) uniform image2D imgInput;
layout(rgba32f, binding = 1) uniform image2D imgOutput;

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dims = imageSize(imgInput);

    if(pixel_coords.x >= dims.x || pixel_coords.y >= dims.y) return;

    vec3 totalColor = vec3(0.0);
    float count = 0.0;

    int radio = 4;

    for(int x = -radio; x <= radio; x++) {
        for(int y = -radio; y <= radio; y++) {
            ivec2 neighbor = pixel_coords + ivec2(x, y);
            
            if(neighbor.x >= 0 && neighbor.x < dims.x && neighbor.y >= 0 && neighbor.y < dims.y) {
                vec3 color = imageLoad(imgInput, neighbor).rgb;
                float brightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
                if(brightness > 1.0) color *= 1.5;

                totalColor += color;
                count += 1.0;
            }
        }
    }
    
    vec3 blurColor = totalColor / count;

    imageStore(imgOutput, pixel_coords, vec4(blurColor, 1.0));
}