#version 330 core
layout (location = 0) in vec2 aPos;

//Enviamos la posición al sombreador de fragmentos para que la sepa
//en qué coordenada de píxel está trabajando.

out vec2 fragCoord;

void main()
{
    //Pasar la posición (-1 a 1) directamente.
    //Esto fija el cuadrante a las esquinas de la pantalla.
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);

    //Pasamos la posición al sombreador de fragmentos.
    fragCoord = aPos;

}