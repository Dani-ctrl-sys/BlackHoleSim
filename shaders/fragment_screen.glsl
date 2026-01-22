// Fragment Shader de Pantalla
// Este shader simplemente lee la textura generada por el compute shader
// y la muestra en la pantalla. Es como un "proyector" que toma la imagen
// renderizada y la pinta en el lienzo.

#version 330 core

// --- SALIDA ---
// El color final que se pintará en la pantalla
out vec4 FragColor;

// --- ENTRADA DESDE EL VERTEX SHADER ---
// Coordenadas normalizadas del píxel actual (rango: -1 a 1)
in vec2 fragCoord;

// --- UNIFORMS ---
// La textura que contiene los píxeles generados por el Compute Shader
uniform sampler2D texOutput;

void main() {
    // --- 1. CONVERTIR COORDENADAS ---
    // fragCoord viene del vertex shader en rango [-1, 1]
    // Las texturas usan UV en rango [0, 1]
    // Formula: [-1,1] → [0,1] = (valor * 0.5) + 0.5
    vec2 uv = fragCoord * 0.5 + 0.5;

    // --- 2. LEER EL COLOR DE LA TEXTURA ---
    // texture() lee el píxel en la coordenada UV especificada
    // .rgb extrae solo los componentes de color (sin alpha)
    vec3 color = texture(texOutput, uv).rgb;

    // --- 3. ESCRIBIR EL COLOR FINAL ---
    // Convertimos vec3 a vec4 añadiendo alpha = 1.0 (opaco)
    FragColor = vec4(color, 1.0);
}
