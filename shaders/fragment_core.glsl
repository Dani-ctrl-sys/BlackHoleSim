#version 330 core
out vec4 FragColor;
in vec2 fragCoord; //Coordenadas provenientes del Vertex Shader (-1.0 a 1.0)

// "uniform" significa que es constante para todos los píxeles en un mismo cuadro,
// pero la CPU puede cambiarla si redimensionas la ventana.
uniform vec2 u_resolution;
uniform vec3 u_camPos; // Recibe la posición de la cámara desde C++
uniform float u_rs; // Radio de Schwarzschild (Horizonte de eventos)

// --- HERRAMIENTAS VISUALES ---

//Función para generar un fondo de cuadrícula (Grid) y estrellas
// Esto nos permite ver la distorsión del espacio-tiempo.
vec3 getBackground(vec3 dir) {
    // Convertimos la dirección 3D a coordenadas esféricas planas
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * 3.14159);
    float v = 0.5 - asin(dir.y) / 3.14159;

    //Generamos una cuadrícula
    // "step" crea líneas nítidas blanco/negro
    float gridColor = 0.0;
    float density = 10.0; // Cuántas celdas tiene la cuadrícula

    // Líneas verticales y horizontales
    float gridX = step(0.98, fract(u * density));
    float gridY = step(0.98, fract(v * density));
    gridColor = max(gridX, gridY);

    // Color base azul oscuro + líneas blancas cian
    return vec3(0.05, 0.05, 0.1) + vec3(0.0, 1.0, 1.0) * gridColor; 

}

// Matriz de Cámara (LookAt): Orienta los rayos hacia un objetivo
mat3 setCamera(in vec3 ro, in vec3 ta, float cr){
    vec3 cw = normalize(ta - ro); // Vector "Forward" (Hacia dónde miro)
    vec3 cp = vec3(sin(cr), cos(cr), 0.0); // Vector "Up" temporal
    vec3 cu = normalize(cross(cw, cp)); // Vector "Right" (Producto cruz)
    vec3 cv = normalize(cross(cu, cw)); // Vector "Up" real
    return mat3(cu, cv, cw);
}

// --- FÍSICA: CÁLCULO DE ACELERACIÓN ---
// Calcula cuánto se curva la luz en una posición 'p' dada
vec3 calculateAccel(vec3 p, vec3 v, float u_rs){
    float r2 = dot(p, p); // Distancia al cuadrado (r^2)
    float r = sqrt(r2); // Distancia al punto (r)

    // Momento angular específico (h = p x v)
    // Se conserva en la órbita, pero necesitamos su magnitud para la fuerza

    vec3 h = cross(p, v);
    float h2 = dot(h, h);

    // Ecuación de geodésica para fotones en Schwarzschild
    // Aceleración = -1.5 * h^2 * Rs / r^5 * vector_posicion
    return -1.5 * h2 * u_rs / (r2 * r) * p;
    
}

void main()
{
    vec2 uv = fragCoord;
    float aspect = u_resolution.x / u_resolution.y;
    uv.x *= aspect;

    // Configuración inicial del Rayo
    vec3 ro = u_camPos; // Posición inicial del fotón
    vec3 ta = vec3(0.0, 0.0, 0.0); // Miramos al agujero negro
    mat3 cam = setCamera(ro, ta, 0.0);
    vec3 rd = cam * normalize(vec3(uv, 2.0)); // Dirección inicial del fotón

    vec3 p = ro; // Punto actual del rayo
    vec3 v = rd; // Ahora 'v' (velocidad) es modificable, 'rd' era la dirección inicial

    // Ajustes para RK4: Pasos más grandes pero precisos
    float stepSize = 0.1;
    int maxSteps = 1000; // Un poco más de margen

    bool hitBlackHole = false;
    float isco = 3.0 * u_rs; // Borde interno (Última órbita estable)
    float outerDisk = 6.0 * u_rs; // Borde externo (hasta donde llega el gas)

    vec3 color = vec3(0.0); // Declaramos color ANTES del bucle

    for(int i = 0; i < maxSteps; i++){

    vec3 p_prev = p; // Guardamos la posición anterior
    float r2 = dot(p, p); // Distancia al cuadrado (r^2)
    float r = sqrt(r2); // Distancia al punto (r)

    // CONDICIONES DE PARADA
    if(r < u_rs){
        hitBlackHole = true;
        break;
    }
    if (r > 25.0){
        break; 
    }

    // --- INTEGRADOR RK4 (Runge-Kutta 4th Order) ---
    // k1, k2, k3, k4 son las 4 "pendientes" o evaluaciones

    // Paso 1: Evaluar en el punto actual
    vec3 k1_v = calculateAccel(p, v, u_rs);
    vec3 k1_p = v;

    // Paso 2: Evaluar a mitad del paso (usando k1)
    vec3 k2_v = calculateAccel(p + k1_p * stepSize * 0.5, v + k1_v * stepSize * 0.5, u_rs);
    vec3 k2_p = v + k1_v * stepSize * 0.5;

    // Paso 3: Evaluar a mitad del paso (usando k2)
    vec3 k3_v = calculateAccel(p + k2_p * stepSize * 0.5, v + k2_v * stepSize * 0.5, u_rs);
    vec3 k3_p = v + k2_v * stepSize * 0.5;

    // 4. Evaluar al final del paso (usando k3)
    vec3 k4_v = calculateAccel(p + k3_p * stepSize, v + k3_v * stepSize, u_rs);
    vec3 k4_p = v + k3_v * stepSize;

    // Promedio ponderado (1/6) para actualizar Posición y Velocidad
    // Fórmula: x_nuevo = x_viejo + (k1 + 2k2 + 2k3 + k4) * dt / 6
    v += (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v) * stepSize / 6.0;
    p += (k1_p + 2.0 * k2_p + 2.0 * k3_p + k4_p) * stepSize / 6.0;

    // --- DETECCIÓN DEL DISCO DE ACRECIÓN  CON INTERPOLACIÓN---
    // Comprobamos si cruzamos el plano Y=0
    if(p_prev.y * p.y < 0.0){

        // MAGIA MATEMÁTICA: Interpolación Lineal (Lerp)
        // Calculamos 't': el porcentaje del salto que dimos antes de chocar.
        // Si t=0.5, chocamos justo a la mitad del camino.
        float t = -p_prev.y / (p.y - p_prev.y);

        // Calculamos el punto EXACTO de intersección
        vec3 p_exacto = p_prev + t * (p - p_prev);

        // Usamos 'p_exacto' para medir la distancia, no 'p'
        float dist = length(p_exacto);

        if(dist > isco && dist < outerDisk){
            float intensity = (outerDisk / dist);
            // Potenciamos un poco el color
            color = vec3(1.0, 0.6, 0.2) * intensity * 1.5;
            hitBlackHole = true;
            break;
        }
      }
    }
   

   if(hitBlackHole){
    // Si hitBlackHole por disco, color ya está asignado
    // Si hitBlackHole por horizonte, pintamos negro
    if(color == vec3(0.0)) color = vec3(0.0);
   } else{
    color = getBackground(normalize(v));
   }

   FragColor = vec4(color, 1.0);
}