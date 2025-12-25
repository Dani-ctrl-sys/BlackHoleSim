#version 330 core
out vec4 FragColor;

//Coordenadas provenientes del Vertex Shader (-1.0 a 1.0)
in vec2 fragCoord;

// Recibimos la imagen generada por la CPU como una textura
uniform sampler2D screenTexture;

void main()
{
    //--- PASO DE DEPURACIÓN ---
    //Visualizar el sistema de coordenadas
    //fragCoord varía de -1 a 1
    //Lo mapeamos de 0 a 1 para la visualización en color

    vec2 uv = fragCoord * 0.5 + 0.5; // Transformar el rango [-1,1] a [0,1]
    FragColor = texture(screenTexture, uv);
}
