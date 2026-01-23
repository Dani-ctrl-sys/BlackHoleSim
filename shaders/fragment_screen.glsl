#version 330 core
out vec4 FragColor;
in vec2 fragCoord;

// Ahora recibimos DOS texturas
uniform sampler2D texBase;  // La nítida (computeTexture)
uniform sampler2D texBloom; // La borrosa (blurTexture)

void main()
{
    vec2 uv = fragCoord * 0.5 + 0.5;

    // 1. Leemos la imagen base (El agujero negro definido)
    vec3 colorBase = texture(texBase, uv).rgb;

    // 2. Leemos el bloom (El resplandor celestial)
    vec3 colorBloom = texture(texBloom, uv).rgb;

    // 3. MEZCLA ADITIVA (La clave de la luz)
    // Luz + Luz = MÁS Luz. 
    // Sumamos la imagen normal + el resplandor.
    vec3 finalColor = colorBase + colorBloom;

    // (Opcional) Tone Mapping simple para que no sature a blanco puro demasiado rápido
    finalColor = vec3(1.0) - exp(-finalColor * 1.0);

    FragColor = vec4(finalColor, 1.0);
}