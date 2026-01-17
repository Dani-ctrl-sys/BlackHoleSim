#version 330 core
out vec4 FragColor;

//Coordenadas provenientes del Vertex Shader (-1.0 a 1.0)
in vec2 fragCoord;

// Recibimos la imagen generada por la CPU como una textura
uniform sampler2D screenTexture;

void main()
{
    // Convertir fragCoord de [-1,1] a [0,1] y voltear Y
    // OpenGL texture coordinates: (0,0) = bottom-left, pero nuestra CPU renderiza (0,0) = top-left
    vec2 uv = fragCoord * 0.5 + 0.5; // [-1,1] -> [0,1]
    uv.y = 1.0 - uv.y; // Voltear Y para coincidir con el sistema de la CPU
    
    FragColor = vec4(texture(screenTexture, uv).rgb, 1.0);
}
