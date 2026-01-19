#version 330 core
out vec4 FragColor;
in vec2 fragCoord; //Coordenadas provenientes del Vertex Shader (-1.0 a 1.0)

// AQUÍ está la variable que mencionamos.
// "uniform" significa que es constante para todos los píxeles en un mismo cuadro,
// pero la CPU puede cambiarla si redimensionas la ventana.
uniform vec2 u_resolution;
uniform vec3 u_camPos; // Recibe la posición de la cámara desde C++

// --- FÍSICA BÁSICA (Aún sin agujero negro, solo visualización) ---
// Función temporal para dibujar una esfera y probar la cámara
float sdSphere(vec3 p, float s){
    return length(p) - s;
}

// Matriz de Cámara (LookAt): Orienta los rayos hacia un objetivo
mat3 setCamera(in vec3 ro, in vec3 ta, float cr){
    vec3 cw = normalize(ta - ro); // Vector "Forward" (Hacia dónde miro)
    vec3 cp = vec3(sin(cr), cos(cr), 0.0); // Vector "Up" temporal
    vec3 cu = normalize(cross(cw, cp)); // Vector "Right" (Producto cruz)
    vec3 cv = normalize(cross(cu, cw)); // Vector "Up" real
    return mat3(cu, cv, cw);
}

void main()
{
    vec2 uv = fragCoord;

    // Corrección de aspecto
    float aspect = u_resolution.x / u_resolution.y;
    uv.x *= aspect;

    // --- CONFIGURACIÓN DE CÁMARA 3D ---
    vec3 ro = u_camPos; // Ray Origin (Posición de la cámara)
    vec3 ta = vec3(0.0, 0.0, 0.0); // Target (Hacia dónde mira)
    
    // Construimos la matriz de rotación de la cámara
    mat3 cam = setCamera(ro, ta, 0.0);

    // Ray Direction:
    // uv.x * Right + uv.y * Up + 2.0 * Forward (2.0 es el Zoom/Campo de visión)
    vec3 rd = cam * normalize(vec3(uv, 2.0));

    // --- VISUALIZACIÓN TEMPORAL (Ray Marching Simple) ---
    vec3 color = vec3(0.0) //Fondo negro

    //Lanzamos el rayo
    float t= 0.0;
    for(int i=0; i<100; i++){
        vec3 p = ro + rd * t; //Punto actual en el espacio
        float d = sdSphere(p, 1.0); // ¿Golpeamos una esfera de radio 1?
        if(d<0.001){
            // Si golpeamos, pintamos la esfera
            vec3 normal = normalize(p);
            color = normal * 0.5 + 0.5; // Colorear según la normal (X,Y,Z -> R,G,B)
            break;
        }
        t += d; // Avanzamos en el rayo
        if(t > 20.0) break; // Muy lejos
    }
    FragColor = vec4(color, 1.0);
}