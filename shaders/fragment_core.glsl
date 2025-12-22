#version 330 core
out vec4 FragColor;

//Coordenadas provenientes del Vertex Shader (-1.0 a 1.0)
in vec2 fragCoord;

//Necesitaremos la resolución de la pantalla más tarde para corregir la relación de aspecto
//uniform vec2 u_resolution;

void main()
{
    //--- PASO DE DEPURACIÓN ---
    //Visualizar el sistema de coordenadas
    //fragCoord varía de -1 a 1
    //Lo mapeamos de 0 a 1 para la visualización en color

    vec2 uv = fragCoord * 0.5 + 0.5; // Transformar el rango [-1,1] a [0,1]

    //Canal rojo = posición X, canal verde = posición Y
    FragColor = vec4(uv.x, uv.y, 0.0, 1.0);
}
