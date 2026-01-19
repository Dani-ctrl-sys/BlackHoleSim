#version 330 core
out vec4 FragColor;
in vec2 fragCoord; //Coordenadas provenientes del Vertex Shader (-1.0 a 1.0)

// "uniform" significa que es constante para todos los píxeles en un mismo cuadro,
// pero la CPU puede cambiarla si redimensionas la ventana.
uniform vec2 u_resolution;
uniform vec3 u_camPos; // Recibe la posición de la cámara desde C++
uniform float u_rs; // Radio de Schwarzschild (Horizonte de eventos)

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
    // 1. Configuración de coordenadas
    vec2 uv = fragCoord;
    float aspect = u_resolution.x / u_resolution.y;
    uv.x *= aspect;

    // 2. Cámara y Rayo inicial
    vec3 ro = u_camPos; // Posición inicial del fotón
    vec3 ta = vec3(0.0, 0.0, 0.0); // Miramos al agujero negro
    mat3 cam = setCamera(ro, ta, 0.0);
    vec3 rd = cam * normalize(vec3(uv, 2.0)); // Dirección inicial del fotón 

    // --- FÍSICA RELATIVISTA (INTEGRACIÓN) ---
    vec3 p = ro; // Punto actual del rayo
    vec3 color = vec3(0.0); // Color del fondo (espacio vacío)

    //Parámetros de la simulación
    float totalDistance = 0.0; 
    float stepSize = 0.1; // "Tamaño del paso". Cuanto más pequeño, más preciso (pero más lento).
    int maxSteps = 300; // Límite de seguridad para no colgar la GPU
    bool hitBlackHole = false;

    for(int i = 0; i < maxSteps; i++){
        // A. Avanzar el rayo (Por ahora en línea recta: Newtoniano)
        // En el próximo paso, aquí añadiremos la GRAVEDAD modificando 'rd'
        p += rd * stepSize;

        // B. Comprobar colisión con el Horizonte de Sucesos
        float distToCenter = length(p);

        // Si la distancia es menor que el Radio de Schwarzschild...
        if(distToCenter < u_rs){
            hitBlackHole = true;
            break; // ¡Atrapado! Deja de calcular.
        }

        // C. Salida de emergencia (Optimizacion)
        // Si el rayo se aleja mucho (  ej: 20 unidades), asumimos que se perdió en el espacio
        if(distToCenter > 20.0f){
            break;
        }
    }

    // --- VISUALIZACIÓN ---
    if(hitBlackHole){
        color = vec3(0.0); // NEGRO ABSOLUTO (La Sombra)
    } else {
        // Fondo de estrellas simple (ruido estático por ahora para ver algo)
        // O simplemente un color grisáceo para diferenciar del negro
        color = vec3(0.2, 0.2, 0.25);
    }

    FragColor = vec4(color, 1.0);
}