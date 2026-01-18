#version 330 core
out vec4 FragColor;
in vec2 fragCoord; //Coordenadas provenientes del Vertex Shader (-1.0 a 1.0)

// AQUÍ está la variable que mencionamos.
// "uniform" significa que es constante para todos los píxeles en un mismo cuadro,
// pero la CPU puede cambiarla si redimensionas la ventana.
uniform vec2 u_resolution;

void main()
{
    // 1. Copiamos la coordenada base
    vec2 uv = fragCoord;

    // 2. Corregimos la relación de aspecto (Aspect Ratio)
    // Si la pantalla es más ancha que alta (ej: 16:9), estiramos la coordenada X.
    // Fórmula: ancho / alto
    float aspect = u_resolution.x / u_resolution.y;
    uv.x *= aspect;

    //--- AQUÍ IRÁ LA FÍSICA PRONTO ---

    // 3. Visualización de prueba (Debug)
    // Convertimos coordenadas (-1 a 1) a colores (0 a 1)
    // X (Rojo), Y (Verde), Azul a 0. 
    vec3 color = vec3(uv.x * 0.5 + 0.5, uv.y * 0.5 + 0.5, 0.0);
    FragColor = vec4(color, 1.0);
}