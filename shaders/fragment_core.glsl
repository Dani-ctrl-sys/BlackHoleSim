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

    // --- FÍSICA RELATIVISTA (INTEGRACIÓN) ---

    vec3 p = ro; // Punto actual del rayo
    vec3 v = rd; // Ahora 'v' (velocidad) es modificable, 'rd' era la dirección inicial

   float stepSize = 0.05; // Pasos más pequeños para mayor precisión
   int maxSteps = 500; // Más pasos porque el camino es curvo
   bool hitBlackHole = false;

   // Acumulador de curvatura (para efectos visuales opcionales)
   float accum = 0.0;

   // Límites del disco (dónde empieza y dónde acaba la materia)
   float isco = 3.0 * u_rs; // Borde interno (Última órbita estable)
   float outerDisk = 6.0 * u_rs; // Borde externo (hasta donde llega el gas)

   vec3 color = vec3(0.0); // Declaramos color ANTES del bucle

   for(int i = 0; i < maxSteps; i++){

    vec3 p_prev = p; // Guardamos la posición anterior

    // 1. Datos actuales
    float r2 = dot(p, p); // Distancia al cuadrado (r^2)
    float r = sqrt(r2); // Distancia al punto (r)

    // 2. Comprobar colisión (Horizonte de Sucesos)
    if(r < u_rs){
        hitBlackHole = true;
        break;
    }

    // 3. Salida de emergencia (Si escapamos al infinito)
    if (r > 20.0){
        break; 
    }

    // --- EL CORAZÓN DE LA RELATIVIDAD ---
    // Ecuación de Geodésicas para la luz en métrica de Schwarzschild.
    // Aceleración = -1.5 * Rs * h^2 / r^5 * vector_posicion
    // Donde h = momento angular (p cruz v)

    vec3 h = cross(p, v); // Momento angular
    float h2 = dot(h, h); // Momento angular al cuadrado

    // Fórmulas simplificadas para GLSL:
    // La gravedad Newtoniana sería proporcional a 1/r^2.
    // La gravedad Einsteiniana para luz es proporcional a 1/r^5.
    // Esto causa que la luz "caiga" muy rápido cerca del horizonte.
    vec3 accel = -1.5 * h2 * u_rs / pow(r2, 2.5) * p;

    // 4. Integración de Euler (Simple)
    v += accel * stepSize; // Cambiamos la DIRECCIÓN del fotón
    p += v * stepSize; // Movemos el fotón

    // --- 5. DETECCIÓN DEL DISCO DE ACRECIÓN ---
    // Lógica: Si antes 'y' era positivo y ahora es negativo (o viceversa), cruzamos el plano Y=0.
    if(p_prev.y * p.y < 0.0){
      float distAlCentro = length(p);

      // ¿Estamos entre el radio interno y el externo?
      if(distAlCentro > isco && distAlCentro < outerDisk){
        // ¡IMPACTO CON EL DISCO!
        color = vec3(1.0, 0.5, 0.1); // Naranja fuego
        color *= (outerDisk / distAlCentro); // Más brillante cerca del centro
        hitBlackHole = true; // Reusamos para no pintar el fondo
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