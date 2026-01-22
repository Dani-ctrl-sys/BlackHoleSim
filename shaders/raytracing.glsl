#version 430
// 1. DEFINICIÓN DEL GRUPO DE TRABAJO
// La GPU agrupa los hilos en bloques. Aquí decimos que cada bloque
// será de 8x8 hilos (64 hilos por grupo).

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 2. LA TEXTURA DE SALIDA (Nuestra "Hoja de Papel")
// rgba32f: Coincide con el GL_RGBA32F de C++
// binding = 0: Coincide con el '0' del glBindImageTexture en C++
layout(rgba32f, binding = 0) uniform image2D imgOutput;

// 3. UNIFORMS (Igual que antes)
uniform float u_time;

void main() {
    // A. OBTENER COORDENADAS
    // Convertimos el ID global en coordenadas de imagen (enteros)
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

    // B. OBTENER TAMAÑO DE IMAGEN
    // Ya no necesitamos pasar u_resolution manualmente,
    // podemos preguntarle a la textura cuánto mide.
    ivec2 dims = imageSize(imgOutput);

    // C. SEGURIDAD
    // Si el hilo está fuera de la imagen (puede pasar si el tamaño
    // no es múltiplo de 8), no hacemos nada para no romper la memoria.
    if(pixel_coords.x >= dims.x || pixel_coords.y >= dims.y) return;

    // --- TEST VISUAL ---
    // Vamos a pintar algo simple para ver si funciona.
    // Un degradado basado en la posición.
    float r = float(pixel_coords.x) / dims.x;
    float g = float(pixel_coords.y) / dims.y;
    vec4 pixel_color = vec4(r, g, 0.0, 1.0);

    // D. ESCRIBIR EN LA MEMORIA
    // En lugar de "FragColor =", usamos imageStore.
    // Parámetros: (Dónde escribir, En qué coordenada, Qué color poner)
    imageStore(imgOutput, pixel_coords, pixel_color);
}